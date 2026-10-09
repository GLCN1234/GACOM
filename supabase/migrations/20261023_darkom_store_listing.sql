-- Darkom City in the game store. Safe to re-run.
insert into game_listings (name, tagline, description, category, developer_name, play_route, is_featured, status, is_gacom_official)
select 'Darkom City', 'An open city. Fight, talk, rule it.',
       'Roam an open 2D city with other players. Take on missions, fight with swords, daggers, hammers, axes, staffs and shields, talk by chat and voice, and join your house squad for realtime arena fights. Weapon skins and looks from the shop show on your fighter.',
       'Action', 'GACOM', '/darkom/hub', true, 'approved', true
where not exists (select 1 from game_listings where name = 'Darkom City');

update game_listings
   set play_route = '/darkom/hub', status = 'approved', is_gacom_official = true, is_featured = true
 where name = 'Darkom City';
