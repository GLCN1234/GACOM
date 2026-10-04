insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Ludo', 'The classic dice race', 'Roll a six to bring your tokens out, capture rivals, and race all four home first. Play against 1 to 3 AI opponents.', 'Board', 'GACOM', '/arena/practice/ludo', true, 'approved', true
where not exists (select 1 from game_listings where name = 'Ludo');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Ayo', 'Traditional African seed strategy', 'Sow seeds around the board and capture 25 to win. A classic West African strategy game, played here with Oware rules, with three AI difficulty levels.', 'Strategy', 'GACOM', '/arena/practice/ayo', true, 'approved', true
where not exists (select 1 from game_listings where name = 'Ayo');
