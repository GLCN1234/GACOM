insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Air Hockey', 'Slide, smash, score', 'A fast table game. Slide your mallet to smash the puck into the AI goal and defend your own. First to 7 goals, or the lead at 3 minutes, wins.', 'Action', 'GACOM', '/arena/practice/airhockey', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Air Hockey');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select '8-Ball Pool', 'Pot your group, sink the 8', 'Full eight-ball pool against the AI. Pull back to shoot, pot solids or stripes, avoid fouls, and sink the 8 ball to win.', 'Strategy', 'GACOM', '/arena/practice/pool', false, 'approved', true
where not exists (select 1 from game_listings where name = '8-Ball Pool');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Pinball', 'Flip, bump, multiply', 'A classic pinball table. Launch the ball, work the flippers, hit the bumpers, and light the top lanes for bonus multipliers up to x5.', 'Arcade', 'GACOM', '/arena/practice/pinball', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Pinball');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Tower Defense', 'Hold the line for 30 waves', 'Build arrow, cannon, frost and sniper towers along the path, upgrade them, and stop 30 waves of enemies and bosses from reaching your base.', 'Strategy', 'GACOM', '/arena/practice/towerdefense', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Tower Defense');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Mini Crossword', 'A fresh 5x5 every time', 'A quick 5x5 crossword with clues across and down. A new puzzle is built every time. Finish fast with few hints for a high score.', 'Puzzle', 'GACOM', '/arena/practice/minicrossword', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Mini Crossword');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Jigsaw Puzzle', 'Rebuild the picture', 'Drag real jigsaw-shaped pieces into place to rebuild the picture. Choose 9, 16 or 25 pieces and five different scenes.', 'Puzzle', 'GACOM', '/arena/practice/jigsaw', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Jigsaw Puzzle');


notify pgrst, 'reload schema';
