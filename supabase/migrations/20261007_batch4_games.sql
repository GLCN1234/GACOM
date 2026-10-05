insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Sky Hopper', 'Tap to flap through the gaps', 'Guide a little bird through an endless run of pipes. Every pipe cleared scores a point, and the gaps get tighter as you go.', 'Arcade', 'GACOM', '/arena/practice/skyhopper', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Sky Hopper');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Dash Runner', 'Jump, slide, run forever', 'An endless runner. Jump crates, slide under high bars, grab coins, and keep up as the speed climbs.', 'Arcade', 'GACOM', '/arena/practice/dashrunner', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Dash Runner');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Star Blaster', 'Fly, shoot, survive the waves', 'A vertical space shooter with weaving enemies, gunships that shoot back, weapon upgrades, shields, and ever harder waves.', 'Action', 'GACOM', '/arena/practice/starblaster', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Star Blaster');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Target Gallery', '60 seconds, hit the targets', 'A fast shooting range. Hit targets for points, build combos up to x5, manage your ammo, and spare the friendly targets.', 'Action', 'GACOM', '/arena/practice/targetgallery', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Target Gallery');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Fruit Slice', 'Swipe to slice, avoid the bombs', 'Slice flying fruit with your finger, chain combos with one swipe, and never touch a bomb. Three missed fruit and you are out.', 'Arcade', 'GACOM', '/arena/practice/fruitslice', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Fruit Slice');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Basketball Shootout', 'Sink as many as you can', 'Pull back and release to throw free shots at a moving hoop. Rim and backboard bounces are real, and streaks score extra.', 'Arcade', 'GACOM', '/arena/practice/basketball', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Basketball Shootout');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Darts', '5 rounds against the AI', 'Throw 3 darts a round on a real dartboard layout. Aim fast before your wobble grows, and beat the AI over 5 rounds.', 'Arcade', 'GACOM', '/arena/practice/darts', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Darts');
