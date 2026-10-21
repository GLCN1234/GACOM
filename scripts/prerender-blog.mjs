// Builds search-engine-readable pages for the GACOM blog after the Flutter build.
//
// The app itself is a single-page Flutter app whose links look like gamicom.net/#/blog/<id>.
// Google does not index those. This script fetches every published post and writes:
//   build/web/blog/index.html              the blog home
//   build/web/blog/<slug>/index.html       one full page per post, with title, description,
//                                          canonical link, Open Graph, Twitter card and JSON-LD
//   build/web/blog/tag/<tag>/index.html    one page per topic, so related searches find us
//   build/web/blog/category/<cat>/index.html
//   build/web/sitemap.xml                  every public page, with last-changed dates
// It never fails the deploy: if the blog cannot be fetched the site still builds.
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const SITE = (process.env.SITE_URL || 'https://gamicom.net').replace(/\/+$/, '');
const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const KEY = process.env.SUPABASE_ANON_KEY || '';
const OUT = process.env.BUILD_DIR || 'build/web';
const BRAND = 'GACOM';
const LOGO = 'https://res.cloudinary.com/dtchp470a/image/upload/c_fill,g_face,h_512,r_max,w_512/v1775540390/WhatsApp_Image_2026-03-27_at_03.12.01_3_jxyhbj.jpg';
const SOCIALS = (process.env.SOCIAL_URLS || '').split(',').map((s) => s.trim()).filter(Boolean);

const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const slugify = (s) => String(s).trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
const stripTags = (h) => String(h ?? '').replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
const clip = (s, n) => (s.length <= n ? s : s.slice(0, n - 1).replace(/\s+\S*$/, '') + '…');

// Posts are written by staff and the daily writer; still, never publish script or event handlers.
function safeHtml(h) {
  return String(h ?? '')
    .replace(/<\s*(script|style|iframe|object|embed|form)[\s\S]*?<\s*\/\s*\1\s*>/gi, '')
    .replace(/<\s*(script|style|iframe|object|embed|form)[^>]*>/gi, '')
    .replace(/\son[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/(href|src)\s*=\s*("|')\s*javascript:[^"']*\2/gi, '$1=$2#$2');
}

async function fetchPosts() {
  if (!SUPABASE_URL || !KEY) throw new Error('SUPABASE_URL or SUPABASE_ANON_KEY missing');
  const select = 'id,title,slug,excerpt,content,cover_image_url,tags,category,published_at,updated_at,read_time_minutes,author:profiles!author_id(display_name,username)';
  const url = `${SUPABASE_URL}/rest/v1/blog_posts?is_published=eq.true&select=${encodeURIComponent(select)}&order=published_at.desc.nullslast&limit=1000`;
  const res = await fetch(url, { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } });
  if (!res.ok) throw new Error(`Supabase answered ${res.status}`);
  return res.json();
}

const CSS = `
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0B0B0F;color:#E9E9F0;font:17px/1.7 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
a{color:#FF8A3D}header,footer{padding:16px 20px;max-width:880px;margin:0 auto}header{display:flex;align-items:center;justify-content:space-between;gap:12px}
.brand{font-weight:800;letter-spacing:.2em;color:#FF6A00;text-decoration:none;font-size:20px}
.cta{background:#FF6A00;color:#fff;text-decoration:none;padding:9px 16px;border-radius:10px;font-weight:700;font-size:15px}
main{max-width:760px;margin:0 auto;padding:8px 20px 40px}h1{font-size:32px;line-height:1.2;margin:.4em 0 .3em}h2{font-size:22px;margin-top:1.8em}
.meta{color:#9A9AA6;font-size:14px}.cover{width:100%;height:auto;border-radius:14px;margin:14px 0;background:#121218}
.tags a{display:inline-block;margin:4px 6px 0 0;padding:3px 10px;border:1px solid #2a2a35;border-radius:20px;text-decoration:none;font-size:13px;color:#cfcfda}
.card{display:block;text-decoration:none;color:inherit;background:#121218;border:1px solid #20202a;border-radius:14px;padding:16px;margin:12px 0}
.card h3{margin:0 0 6px;font-size:19px;color:#fff}.card p{margin:0;color:#b5b5c2;font-size:15px}
.box{background:#121218;border:1px solid #FF6A00;border-radius:14px;padding:18px;margin:32px 0}
footer{color:#7b7b8a;font-size:13px;border-top:1px solid #1c1c25}nav.crumbs{font-size:14px;color:#9A9AA6;margin-top:8px}
`;

function layout({ title, description, path, image, type = 'website', jsonld = [], body, noindex = false }) {
  const canonical = `${SITE}${path}`;
  const img = image || LOGO;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${esc(canonical)}">
<meta name="robots" content="${noindex ? 'noindex,follow' : 'index,follow,max-image-preview:large,max-snippet:-1'}">
<meta property="og:site_name" content="${BRAND}">
<meta property="og:type" content="${type}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(canonical)}">
<meta property="og:image" content="${esc(img)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta name="twitter:image" content="${esc(img)}">
<meta name="theme-color" content="#FF6A00">
<link rel="icon" type="image/png" href="/icons/Icon-192.png">
<link rel="alternate" type="application/rss+xml" title="${BRAND} Blog" href="${SITE}/blog/feed.xml">
${jsonld.map((j) => `<script type="application/ld+json">${JSON.stringify(j).replace(/</g, '\\u003c')}</script>`).join('\n')}
<style>${CSS}</style>
</head>
<body>
<header><a class="brand" href="/">${BRAND}</a><a class="cta" href="/">Open ${BRAND}</a></header>
<main>
${body}
</main>
<footer>
<p>${BRAND} Brands, a product of Mobtech Synergies Ltd (RC-7477445), Ajah, Lagos, Nigeria.</p>
<p><a href="/blog/">Blog</a> &middot; <a href="/download/">Download the app</a> &middot; <a href="/privacy/">Privacy</a></p>
</footer>
</body>
</html>`;
}

const orgLd = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: BRAND,
  url: SITE,
  logo: LOGO,
  parentOrganization: { '@type': 'Organization', name: 'Mobtech Synergies Ltd' },
  address: { '@type': 'PostalAddress', addressLocality: 'Ajah, Lagos', addressCountry: 'NG' },
  ...(SOCIALS.length ? { sameAs: SOCIALS } : {}),
};

const dateOf = (p) => p.updated_at || p.published_at;
const urlOf = (p) => `/blog/${p.slug}/`;

function card(p) {
  return `<a class="card" href="${urlOf(p)}"><h3>${esc(p.title)}</h3><p>${esc(clip(p.excerpt || stripTags(p.content), 160))}</p></a>`;
}

function tagsOf(p) {
  return (p.tags || []).map((t) => String(t).trim()).filter(Boolean).slice(0, 8);
}

function postPage(p, all) {
  const text = stripTags(p.content);
  const description = clip(p.excerpt ? stripTags(p.excerpt) : text, 158);
  const withBrand = `${p.title} | ${BRAND}`;
  const title = withBrand.length <= 62 ? withBrand : clip(p.title, 62);
  const author = p.author?.display_name || `${BRAND} Team`;
  const path = urlOf(p);
  const words = text.split(/\s+/).filter(Boolean).length;
  const tags = tagsOf(p);
  const related = all
    .filter((o) => o.id !== p.id && (o.category === p.category || tagsOf(o).some((t) => tags.includes(t))))
    .slice(0, 3);
  const jsonld = [
    orgLd,
    {
      '@context': 'https://schema.org',
      '@type': 'BlogPosting',
      headline: clip(p.title, 110),
      description,
      image: p.cover_image_url ? [p.cover_image_url] : [LOGO],
      datePublished: p.published_at,
      dateModified: dateOf(p),
      wordCount: words,
      inLanguage: 'en',
      articleSection: p.category || 'News',
      keywords: tags.join(', ') || undefined,
      mainEntityOfPage: { '@type': 'WebPage', '@id': `${SITE}${path}` },
      author: { '@type': 'Organization', name: author === `${BRAND} Team` ? BRAND : author },
      publisher: { '@type': 'Organization', name: BRAND, logo: { '@type': 'ImageObject', url: LOGO } },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: BRAND, item: `${SITE}/` },
        { '@type': 'ListItem', position: 2, name: 'Blog', item: `${SITE}/blog/` },
        { '@type': 'ListItem', position: 3, name: p.title, item: `${SITE}${path}` },
      ],
    },
  ];
  const when = p.published_at ? new Date(p.published_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }) : '';
  const body = `
<nav class="crumbs"><a href="/">${BRAND}</a> / <a href="/blog/">Blog</a>${p.category ? ` / <a href="/blog/category/${slugify(p.category)}/">${esc(p.category)}</a>` : ''}</nav>
<article>
<h1>${esc(p.title)}</h1>
<p class="meta">By ${esc(author)}${when ? ` &middot; <time datetime="${esc(p.published_at)}">${when}</time>` : ''} &middot; ${Math.max(1, p.read_time_minutes || Math.round(words / 200))} min read</p>
${p.cover_image_url ? `<img class="cover" src="${esc(p.cover_image_url)}" alt="${esc(p.title)}" loading="eager" decoding="async">` : ''}
${safeHtml(p.content)}
</article>
${tags.length ? `<p class="tags">${tags.map((t) => `<a href="/blog/tag/${slugify(t)}/">${esc(t)}</a>`).join('')}</p>` : ''}
<div class="box"><strong>Play, compete and learn on ${BRAND}.</strong><br>Join Africa's social gaming platform: tournaments, missions, and GACOM Edu for students.<br><br><a class="cta" href="/">Join ${BRAND}</a></div>
${related.length ? `<h2>More from the ${BRAND} blog</h2>${related.map(card).join('')}` : ''}`;
  return layout({ title, description, path, image: p.cover_image_url, type: 'article', jsonld, body });
}

function listPage({ title, description, path, heading, intro, posts, extra = '' }) {
  const jsonld = [
    orgLd,
    {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      name: heading,
      description,
      url: `${SITE}${path}`,
      isPartOf: { '@type': 'WebSite', name: BRAND, url: SITE },
    },
  ];
  const body = `<h1>${esc(heading)}</h1><p class="meta">${esc(intro)}</p>${extra}${posts.map(card).join('') || '<p>No posts yet.</p>'}`;
  return layout({ title, description, path, jsonld, body });
}

async function write(rel, html) {
  const file = join(OUT, rel);
  await mkdir(join(file, '..'), { recursive: true });
  await writeFile(file, html, 'utf8');
}

async function main() {
  const posts = await fetchPosts();
  console.log(`Prerendering ${posts.length} blog posts`);
  const urls = [
    { loc: '/', pri: '1.0' },
    { loc: '/blog/', pri: '0.9', last: posts[0] && dateOf(posts[0]) },
    { loc: '/download/', pri: '0.7' },
    { loc: '/privacy/', pri: '0.3' },
  ];

  for (const p of posts) {
    if (!p.slug) continue;
    await write(`blog/${p.slug}/index.html`, postPage(p, posts));
    urls.push({ loc: urlOf(p), pri: '0.8', last: dateOf(p) });
  }

  await write('blog/index.html', listPage({
    title: `${BRAND} Blog: gaming news, esports and student gaming in Africa`,
    description: `News, tournaments, tips and community stories from ${BRAND}, Africa's social gaming platform with GACOM Edu for students.`,
    path: '/blog/',
    heading: `${BRAND} Blog`,
    intro: 'Gaming news, esports, tournaments, tips and community stories from Nigeria and across Africa.',
    posts,
  }));

  const byTag = new Map();
  const byCat = new Map();
  for (const p of posts) {
    for (const t of tagsOf(p)) {
      const k = slugify(t);
      if (!k) continue;
      if (!byTag.has(k)) byTag.set(k, { name: t, posts: [] });
      byTag.get(k).posts.push(p);
    }
    if (p.category) {
      const k = slugify(p.category);
      if (!byCat.has(k)) byCat.set(k, { name: p.category, posts: [] });
      byCat.get(k).posts.push(p);
    }
  }
  for (const [k, v] of [...byTag].slice(0, 300)) {
    await write(`blog/tag/${k}/index.html`, listPage({
      title: `${v.name}: posts and news | ${BRAND} Blog`,
      description: `Everything ${BRAND} has published about ${v.name}.`,
      path: `/blog/tag/${k}/`,
      heading: v.name,
      intro: `${v.posts.length} post${v.posts.length === 1 ? '' : 's'} about ${v.name}.`,
      posts: v.posts,
    }));
    urls.push({ loc: `/blog/tag/${k}/`, pri: '0.5', last: dateOf(v.posts[0]) });
  }
  for (const [k, v] of byCat) {
    await write(`blog/category/${k}/index.html`, listPage({
      title: `${v.name} | ${BRAND} Blog`,
      description: `${v.name} stories and updates from ${BRAND}.`,
      path: `/blog/category/${k}/`,
      heading: v.name,
      intro: `${v.posts.length} post${v.posts.length === 1 ? '' : 's'} in ${v.name}.`,
      posts: v.posts,
    }));
    urls.push({ loc: `/blog/category/${k}/`, pri: '0.6', last: dateOf(v.posts[0]) });
  }

  const feed = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>${BRAND} Blog</title><link>${SITE}/blog/</link><description>Gaming news, esports and student gaming from ${BRAND}.</description>
${posts.slice(0, 30).map((p) => `<item><title>${esc(p.title)}</title><link>${SITE}${urlOf(p)}</link><guid>${SITE}${urlOf(p)}</guid>${p.published_at ? `<pubDate>${new Date(p.published_at).toUTCString()}</pubDate>` : ''}<description>${esc(clip(p.excerpt || stripTags(p.content), 300))}</description></item>`).join('\n')}
</channel></rss>`;
  await write('blog/feed.xml', feed);

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((u) => `<url><loc>${SITE}${u.loc}</loc>${u.last ? `<lastmod>${new Date(u.last).toISOString().slice(0, 10)}</lastmod>` : ''}<priority>${u.pri}</priority></url>`).join('\n')}
</urlset>`;
  await write('sitemap.xml', sitemap);
  await write('robots.txt', `User-agent: *\nAllow: /\nDisallow: /admin\nSitemap: ${SITE}/sitemap.xml\n`);
  console.log(`Wrote ${urls.length} pages and the sitemap`);
}

main().catch((e) => {
  console.warn(`Blog prerender skipped: ${e.message}`);
  process.exit(0);
});
