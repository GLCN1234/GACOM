insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Checkers', 'Classic draughts vs the AI', 'Move diagonally, capture by jumping, and crown kings. Captures are mandatory. Play against an AI at three difficulty levels.', 'Board', 'GACOM', '/arena/practice/checkers', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Checkers');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Battleship', 'Sink the enemy fleet', 'Place your fleet, then trade shots with the AI. Find and sink all five enemy ships before they sink yours.', 'Strategy', 'GACOM', '/arena/practice/battleship', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Battleship');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Rummy', 'Form sets and runs, then go out', 'Draw, meld sets and runs, lay off cards on the table, and go out first to score the points left in the AI hand.', 'Card', 'GACOM', '/arena/practice/rummy', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Rummy');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Solitaire', 'Classic Klondike', 'Build the four suit piles from Ace to King. Draw one or draw three, with unlimited undo.', 'Card', 'GACOM', '/arena/practice/solitaire', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Solitaire');

insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Chess Puzzle Rush', '3 minutes, 3 strikes', 'Solve as many chess tactics as you can before time runs out. A new puzzle set every day, the same for everyone.', 'Puzzle', 'GACOM', '/arena/practice/puzzlerush', false, 'approved', true
where not exists (select 1 from game_listings where name = 'Chess Puzzle Rush');
