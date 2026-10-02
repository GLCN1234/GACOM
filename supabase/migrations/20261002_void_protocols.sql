insert into game_listings (name, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Void Protocols', 'Match beam frequencies to shield-phased anomalies, freeze time to line up shots, and override power nodes with real vector alignment — a Physics/Math action shooter.', 'Action', 'GACOM', '/arena/store/void-protocols', true, 'approved', true
where not exists (select 1 from game_listings where name = 'Void Protocols');
