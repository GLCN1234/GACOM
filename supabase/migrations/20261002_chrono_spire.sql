insert into game_listings (name, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Chrono-Spire', 'Chain Acid into Thermal for a real exothermic combo, and target weak points to slow or disable bio-beasts — a Chemistry/Biology twin-stick shooter.', 'Action', 'GACOM', '/arena/store/chrono-spire', true, 'approved', true
where not exists (select 1 from game_listings where name = 'Chrono-Spire');
