insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Sudoku', 'Every puzzle has one solution', 'Fill the grid so every row, column and box holds 1 to 9. Three difficulty levels, notes, hints and undo.', 'Puzzle', 'GACOM', '/arena/practice/sudoku', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Sudoku');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Block Drop', 'Stack blocks and clear lines', 'Guide falling blocks into place and clear full lines. Hold pieces, see a ghost preview, and survive as it speeds up.', 'Puzzle', 'GACOM', '/arena/practice/blockdrop', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Block Drop');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Color Clash', 'Match colours, empty your hand', 'A fast card game for 2 to 4 players. Match colours and numbers, play Skip, Reverse, Draw Two and Wild cards, and go out first.', 'Card', 'GACOM', '/arena/practice/colorclash', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Color Clash');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Bubble Shooter', 'Aim, match, and pop', 'Shoot bubbles to match three or more. Bounce shots off the walls, drop whole clusters, and clear the board.', 'Arcade', 'GACOM', '/arena/practice/bubbleshooter', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Bubble Shooter');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Stack Tower', 'One tap. How high can you go?', 'Tap to drop the sliding block and build a tower. Perfect drops keep it wide, and every miss trims it down.', 'Arcade', 'GACOM', '/arena/practice/stacktower', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Stack Tower');
