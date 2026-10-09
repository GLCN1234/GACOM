import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gacom_snackbar.dart';
import '../support_service.dart';
import '../support_ui.dart';

/// Admin setup for the support desk: teams, routing, knowledge, training data.
class SupportAdminScreen extends StatefulWidget {
  const SupportAdminScreen({super.key});

  @override
  State<SupportAdminScreen> createState() => _SupportAdminScreenState();
}

class _SupportAdminScreenState extends State<SupportAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<SupportTeam> _teams = [];
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _boot();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final t = await SupportService.allTeams();
    if (!mounted) return;
    setState(() {
      _teams = t;
      _booting = false;
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppConstants.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_booting && _teams.isNotEmpty;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text('SUPPORT SETUP', style: SupportUi.heading(size: 20)),
        bottom: ready
            ? TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: GacomColors.deepOrange,
                labelColor: GacomColors.deepOrange,
                unselectedLabelColor: GacomColors.textMuted,
                labelStyle: SupportUi.heading(size: 14),
                tabs: const [
                  Tab(text: 'TEAMS'),
                  Tab(text: 'ROUTING'),
                  Tab(text: 'KNOWLEDGE'),
                  Tab(text: 'TRAINING'),
                ],
              )
            : null,
      ),
      body: _booting
          ? const SupportLoading()
          : _teams.isEmpty
              ? const SupportEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: 'Admins only',
                  subtitle:
                      'Support setup is for GACOM admins. If you should have access, ask an admin.')
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _TeamsTab(teams: _teams),
                    _RoutingTab(teams: _teams),
                    const _KnowledgeTab(),
                    const _TrainingTab(),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Teams and members
// ---------------------------------------------------------------------------

class _TeamsTab extends StatefulWidget {
  final List<SupportTeam> teams;
  const _TeamsTab({required this.teams});

  @override
  State<_TeamsTab> createState() => _TeamsTabState();
}

class _TeamsTabState extends State<_TeamsTab>
    with AutomaticKeepAliveClientMixin {
  late SupportTeam _team = widget.teams.first;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await SupportService.teamMembers(_team.key);
    if (!mounted) return;
    setState(() {
      _members = m;
      _loading = false;
    });
  }

  void _toast(bool ok, String good, String bad) {
    if (!mounted) return;
    GacomSnackbar.show(context, ok ? good : bad, isSuccess: ok, isError: !ok);
  }

  Future<void> _change(Map<String, dynamic> m,
      {String? role, bool? active}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await SupportService.setTeamMember(
        _team.key, m['userId']?.toString() ?? '',
        role: role ?? (m['role']?.toString() ?? 'agent'),
        active: active ?? (m['active'] != false));
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(ok, 'Saved', 'Could not save this change');
    if (ok) _load();
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final name = m['name']?.toString() ?? 'this person';
    final yes = await supportConfirm(
        context, 'Remove member', 'Remove $name from ${_team.name}?',
        confirm: 'Remove');
    if (!yes) return;
    final ok = await SupportService.removeTeamMember(
        _team.key, m['userId']?.toString() ?? '');
    _toast(ok, 'Removed', 'Could not remove this member');
    if (ok) _load();
  }

  Future<void> _add() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.surfaceDark,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked == null || !mounted) return;
    String role = 'agent';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: GacomColors.elevatedCard,
          title: Text('Add to ${_team.name}', style: SupportUi.heading(size: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(picked['name']?.toString() ?? 'User',
                style: SupportUi.heading(size: 16)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              dropdownColor: GacomColors.elevatedCard,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'agent', child: Text('Agent')),
                DropdownMenuItem(value: 'lead', child: Text('Lead')),
              ],
              onChanged: (v) => setD(() => role = v ?? role),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (go != true) return;
    final ok = await SupportService.setTeamMember(
        _team.key, picked['id']?.toString() ?? '',
        role: role, active: true);
    _toast(ok, 'Member added', 'Could not add this person');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: GacomColors.elevatedCard,
                value: _team.key,
                style: SupportUi.heading(size: 16),
                items: [
                  for (final t in widget.teams)
                    DropdownMenuItem(value: t.key, child: Text(t.name)),
                ],
                onChanged: (k) {
                  if (k == null) return;
                  setState(() =>
                      _team = widget.teams.firstWhere((t) => t.key == k));
                  _load();
                },
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add member'),
          ),
        ]),
      ),
      if (_team.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_team.description, style: SupportUi.muted)),
        ),
      Expanded(
        child: RefreshIndicator(
          color: GacomColors.deepOrange,
          onRefresh: _load,
          child: _loading
              ? ListView(children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: const SupportLoading())
                ])
              : _members.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const SupportEmpty(
                            icon: Icons.groups_outlined,
                            title: 'No members yet',
                            subtitle:
                                'Add people so new requests can be assigned to them.'),
                      ),
                    ])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _memberTile(_members[i]),
                    ),
        ),
      ),
    ]);
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final active = m['active'] != false;
    final role = m['role']?.toString() ?? 'agent';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SupportUi.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['name']?.toString() ?? 'Member',
                  style: SupportUi.heading(size: 16)),
              Text(
                  '${(m['username'] ?? '').toString().isEmpty ? '' : '@${m['username']}  |  '}${m['open'] ?? 0} open',
                  style: SupportUi.muted),
            ]),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded,
                color: GacomColors.error),
            onPressed: () => _remove(m),
          ),
        ]),
        Row(children: [
          DropdownButton<String>(
            value: role == 'lead' ? 'lead' : 'agent',
            dropdownColor: GacomColors.elevatedCard,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'agent', child: Text('Agent')),
              DropdownMenuItem(value: 'lead', child: Text('Lead')),
            ],
            onChanged: (v) {
              if (v != null && v != role) _change(m, role: v);
            },
          ),
          const Spacer(),
          Text(active ? 'Active' : 'Paused', style: SupportUi.muted),
          Switch(
            value: active,
            activeColor: GacomColors.deepOrange,
            onChanged: (v) => _change(m, active: v),
          ),
        ]),
      ]),
    );
  }
}

class _UserSearchSheet extends StatefulWidget {
  const _UserSearchSheet();

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = v.trim();
      if (q.length < 2) {
        setState(() {
          _results = [];
          _searched = false;
        });
        return;
      }
      setState(() => _loading = true);
      final r = await SupportService.findUsers(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
        _searched = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                  hintText: 'Search by name or username',
                  prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: _loading
                ? const SupportLoading()
                : _results.isEmpty
                    ? SupportEmpty(
                        icon: Icons.person_search_rounded,
                        title: _searched ? 'No one found' : 'Find a person',
                        subtitle: _searched
                            ? 'Try a different name or username.'
                            : 'Type at least two letters.')
                    : ListView(children: [
                        for (final u in _results)
                          ListTile(
                            leading: const Icon(Icons.person_outline_rounded),
                            title: Text(u['name']?.toString() ?? 'User'),
                            subtitle: Text(
                                (u['username'] ?? '').toString().isEmpty
                                    ? ''
                                    : '@${u['username']}',
                                style: SupportUi.muted),
                            onTap: () => Navigator.pop(context, u),
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

class _RoutingTab extends StatefulWidget {
  final List<SupportTeam> teams;
  const _RoutingTab({required this.teams});

  @override
  State<_RoutingTab> createState() => _RoutingTabState();
}

class _RoutingTabState extends State<_RoutingTab>
    with AutomaticKeepAliveClientMixin {
  List<SupportCategory> _cats = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await SupportService.categories();
    if (!mounted) return;
    setState(() {
      _cats = c;
      _loading = false;
    });
  }

  Future<void> _set(SupportCategory c, String team) async {
    final ok = await SupportService.setCategoryTeam(c.key, team);
    if (!mounted) return;
    GacomSnackbar.show(context, ok ? 'Routing saved' : 'Could not save routing',
        isSuccess: ok, isError: !ok);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: _load,
      child: _loading
          ? ListView(children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: const SupportLoading())
            ])
          : _cats.isEmpty
              ? ListView(children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const SupportEmpty(
                        icon: Icons.alt_route_rounded,
                        title: 'No categories found',
                        subtitle: 'Pull down to try again.'),
                  ),
                ])
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                          'Choose which team receives each kind of request.',
                          style: TextStyle(color: GacomColors.textSecondary)),
                    ),
                    for (final c in _cats)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        decoration: SupportUi.card(),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  c.label.isEmpty
                                      ? SupportUi.pretty(c.key)
                                      : c.label,
                                  style: SupportUi.heading(size: 15))),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: widget.teams.any((t) => t.key == c.teamKey)
                                ? c.teamKey
                                : null,
                            hint: const Text('Pick a team'),
                            dropdownColor: GacomColors.elevatedCard,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final t in widget.teams)
                                DropdownMenuItem(
                                    value: t.key, child: Text(t.name)),
                            ],
                            onChanged: (v) {
                              if (v != null && v != c.teamKey) _set(c, v);
                            },
                          ),
                        ]),
                      ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Knowledge base
// ---------------------------------------------------------------------------

class _KnowledgeTab extends StatefulWidget {
  const _KnowledgeTab();

  @override
  State<_KnowledgeTab> createState() => _KnowledgeTabState();
}

class _KnowledgeTabState extends State<_KnowledgeTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _drafts = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await SupportService.kbArticles(draftsOnly: _drafts);
    if (!mounted) return;
    setState(() {
      _items = r;
      _loading = false;
    });
  }

  Future<void> _edit([Map<String, dynamic>? a]) async {
    final cats = await SupportService.categories();
    if (!mounted) return;
    final titleCtrl = TextEditingController(text: a?['title']?.toString() ?? '');
    final bodyCtrl = TextEditingController(text: a?['body']?.toString() ?? '');
    String? cat = a?['category_key']?.toString();
    if (cat != null && !cats.any((c) => c.key == cat)) cat = null;
    bool published = a?['published'] == true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: GacomColors.elevatedCard,
          title: Text(a == null ? 'New article' : 'Edit article',
              style: SupportUi.heading(size: 18)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Question or title')),
              const SizedBox(height: 12),
              TextField(
                  controller: bodyCtrl,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Answer')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: cat,
                isExpanded: true,
                dropdownColor: GacomColors.elevatedCard,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Any')),
                  for (final c in cats)
                    DropdownMenuItem<String?>(value: c.key, child: Text(c.label)),
                ],
                onChanged: (v) => setD(() => cat = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text(
                    'Published articles are used to answer users.',
                    style: SupportUi.muted),
                value: published,
                activeColor: GacomColors.deepOrange,
                onChanged: (v) => setD(() => published = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    // Controllers are left to the garbage collector: the dialog's exit animation still reads them.
    if (go != true || !mounted) return;
    if (title.isEmpty || body.isEmpty) {
      GacomSnackbar.show(context, 'Add both a title and an answer', isError: true);
      return;
    }
    final ok = await SupportService.saveKbArticle(
        id: a?['id']?.toString(),
        title: title,
        body: body,
        categoryKey: cat,
        published: published);
    if (!mounted) return;
    GacomSnackbar.show(context, ok ? 'Article saved' : 'Could not save the article',
        isSuccess: ok, isError: !ok);
    if (ok) _load();
  }

  Future<void> _togglePublish(Map<String, dynamic> a, bool v) async {
    final ok = await SupportService.saveKbArticle(
        id: a['id']?.toString(),
        title: a['title']?.toString() ?? '',
        body: a['body']?.toString() ?? '',
        categoryKey: a['category_key']?.toString(),
        published: v);
    if (!mounted) return;
    GacomSnackbar.show(
        context,
        ok ? (v ? 'Published' : 'Moved to drafts') : 'Could not update the article',
        isSuccess: ok,
        isError: !ok);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          ChoiceChip(
            label: const Text('All'),
            selected: !_drafts,
            onSelected: (_) {
              setState(() => _drafts = false);
              _load();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Drafts'),
            selected: _drafts,
            onSelected: (_) {
              setState(() => _drafts = true);
              _load();
            },
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New article'),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          color: GacomColors.deepOrange,
          onRefresh: _load,
          child: _loading
              ? ListView(children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: const SupportLoading())
                ])
              : _items.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: SupportEmpty(
                            icon: Icons.menu_book_outlined,
                            title: _drafts ? 'No drafts' : 'No articles yet',
                            subtitle:
                                'Articles you publish are used to answer users. Agents can also save answers as drafts.'),
                      ),
                    ])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _tile(_items[i]),
                    ),
        ),
      ),
    ]);
  }

  Widget _tile(Map<String, dynamic> a) {
    final pub = a['published'] == true;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _edit(a),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: SupportUi.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(a['title']?.toString() ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SupportUi.heading(size: 15))),
            SupportChip(pub ? 'Published' : 'Draft',
                pub ? GacomColors.success : GacomColors.warning),
          ]),
          const SizedBox(height: 4),
          Text(a['body']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: GacomColors.textSecondary, fontSize: 13)),
          Row(children: [
            if ((a['category_key'] ?? '').toString().isNotEmpty)
              Text(SupportUi.pretty(a['category_key'].toString()),
                  style: SupportUi.muted),
            const Spacer(),
            Text(pub ? 'Live' : 'Not live', style: SupportUi.muted),
            Switch(
              value: pub,
              activeColor: GacomColors.deepOrange,
              onChanged: (v) => _togglePublish(a, v),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Training export
// ---------------------------------------------------------------------------

class _TrainingTab extends StatefulWidget {
  const _TrainingTab();

  @override
  State<_TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<_TrainingTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await SupportService.trainingExport(limit: 200);
    if (!mounted) return;
    setState(() {
      _rows = r;
      _loading = false;
    });
  }

  String _lines() {
    final b = StringBuffer();
    for (final r in _rows) {
      try {
        b.writeln(jsonEncode(r));
      } catch (_) {}
    }
    return b.toString();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _lines()));
    if (!mounted) return;
    GacomSnackbar.show(context, '${_rows.length} conversations copied',
        isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: GacomColors.deepOrange,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: SupportUi.card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TRAINING DATA', style: SupportUi.heading(size: 16)),
              const SizedBox(height: 6),
              const Text(
                  'Resolved conversations with agent answers, corrections and ratings, one JSON object per line. '
                  'Names, card-like numbers and passwords are removed before export. '
                  'Use it to review and improve the assistant. It never leaves the app unless you copy it.',
                  style: TextStyle(color: GacomColors.textSecondary, height: 1.4)),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(12), child: SupportLoading()))
              else ...[
                Text('${_rows.length} conversations ready',
                    style: SupportUi.heading(size: 20, color: GacomColors.deepOrange)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _rows.isEmpty ? null : _copy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy JSON lines'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _load, child: const Text('Refresh')),
                ]),
              ],
            ]),
          ),
          if (!_loading && _rows.isEmpty)
            const SizedBox(
              height: 260,
              child: SupportEmpty(
                  icon: Icons.dataset_outlined,
                  title: 'Nothing to export yet',
                  subtitle: 'Resolved conversations will appear here.'),
            ),
          if (!_loading && _rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('PREVIEW',
                style: SupportUi.heading(size: 12, color: GacomColors.textMuted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: SupportUi.card(),
              child: Text(
                  _lines().split('\n').take(3).map((l) => l.length > 400 ? '${l.substring(0, 400)}...' : l).join('\n\n'),
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: GacomColors.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}
