INSERT INTO title_levels VALUES (1, 0);
INSERT INTO title_levels VALUES (2, 200);
INSERT INTO title_levels VALUES (3, 400);
INSERT INTO title_levels VALUES (4, 800);
INSERT INTO title_levels VALUES (5, 1500);
INSERT INTO title_levels VALUES (6, 2500);
INSERT INTO title_levels VALUES (7, 3750);
INSERT INTO title_levels VALUES (8, 5000);
INSERT INTO title_levels VALUES (9, 7000);
INSERT INTO title_levels VALUES (10, 9000);
INSERT INTO title_levels VALUES (11, 12000);
INSERT INTO title_levels VALUES (12, 15000);
INSERT INTO title_levels VALUES (13, 18000);
INSERT INTO title_levels VALUES (14, 21000);
INSERT INTO title_levels VALUES (15, 25000);
INSERT INTO title_levels VALUES (16, 29000);
INSERT INTO title_levels VALUES (17, 33000);
INSERT INTO title_levels VALUES (18, 40000);
INSERT INTO title_levels VALUES (19, 50000);
INSERT INTO title_levels VALUES (20, 70000);
INSERT INTO title_levels VALUES (21, 100000);

INSERT INTO title_sets (id, name, default_weapon_id) VALUES (
    0,
    'Newbie',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'cluebat0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 0, 1, 'Newbie' );

INSERT INTO title_sets (name, default_weapon_id) VALUES (
    'Knight',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'sword0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 1, 'Slave' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 2, 'Servant' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 3, 'Serf' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 4, 'Peon' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 5, 'Peasant' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 6, 'Head Servant' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 7, 'Vassal' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 8, 'Noble' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 9, 'Squire' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 10, 'Elder Squire' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 11, 'Knight in Training' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 12, 'New Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 13, 'Ordinary Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 14, 'Veteran Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 15, 'Bronze Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 16, 'Azure Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 17, 'Silver Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 18, 'Gold Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 19, 'Platinum Knight' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 20, 'Paladin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 1, 21, 'Grand Paladin' );

INSERT INTO title_sets (name, default_weapon_id) VALUES (
    'Archer',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'bow0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 1, 'Insult Hurler' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 2, 'Mud Slinger' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 3, 'Spitballer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 4, 'Pea Shooter' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 5, 'Stone Thrower' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 6, 'Slinger' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 7, 'Archery Student' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 8, 'Archer in Training' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 9, 'New Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 10, 'Amateur Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 11, 'Experienced Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 12, 'Veteran Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 13, 'Marksman' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 14, 'Expert Marksman' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 15, 'Sharpshooter' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 16, 'Powershooter' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 17, 'High Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 18, 'Crystal Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 19, 'Emerald Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 20, 'Diamond Archer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 2, 21, 'Master Archer' );

INSERT INTO title_sets (name, default_weapon_id) VALUES (
    'Rogue',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'dagger0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 1, 'Bad Liar' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 2, 'Urchin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 3, 'Punk' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 4, 'Swindler' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 5, 'Trickster' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 6, 'Pickpocket' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 7, 'Burglar' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 8, 'Common Thief' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 9, 'Robber' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 10, 'Bandit' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 11, 'Highwayman' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 12, 'Marauder' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 13, 'Green Rogue' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 14, 'Blue Rogue' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 15, 'Brown Rogue' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 16, 'Red Rogue' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 17, 'Grey Rogue' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 18, 'Black Rogue' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 19, 'Lesser Assassin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 20, 'Greater Assassin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 3, 21, 'Master Assassin' );

INSERT INTO title_sets (name, default_weapon_id) VALUES (
    'Martial Artist',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'staff0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 1, 'Wuss' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 2, 'Bully' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 3, 'Rabblerouser' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 4, 'Brawler' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 5, 'White Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 6, 'Yellow Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 7, 'Orange Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 8, 'Green Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 9, 'Blue Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 10, 'Brown Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 11, '1st Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 12, '2nd Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 13, '3rd Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 14, '4th Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 15, '5th Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 16, '6th Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 17, '7th Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 18, '8th Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 19, '9th Dan Black Belt' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 20, 'Sensei' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 4, 21, 'Grandmaster' );

INSERT INTO title_sets (name, default_weapon_id) VALUES (
    'Barbarian',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'mace0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 1, 'Cretin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 2, 'Clod' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 3, 'Neanderthal' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 4, 'Troglodyte' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 5, 'Brute' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 6, 'Savage' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 7, 'Nomad' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 8, 'Wanderer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 9, 'Scavenger' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 10, 'Hunter' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 11, 'Barbarian' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 12, 'Raider' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 13, 'Ranger' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 14, 'Warrior' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 15, 'Strong Warrior' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 16, 'Mighty Warrior' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 17, 'Barbarian Leader' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 18, 'Barbarian Commander' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 19, 'Barbarian General' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 20, 'Barbarian Chief' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 5, 21, 'Barbarian King' );

INSERT INTO title_sets (name, default_weapon_id) VALUES (
    'Samurai',
    ( SELECT weapons.id FROM weapons WHERE weapons.code = 'katana0' )
);
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 1, 'Sushi Chef' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 2, 'Iron Chef' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 3, 'Unarmed Samurai' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 4, 'Butterknifer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 5, 'Wooden Swordsman' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 6, 'Rusty Swordsman' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 7, 'Dull Swordsman' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 8, 'Ronin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 9, 'Kenin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 10, 'Ashigaru' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 11, 'Samurai' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 12, 'Sohei' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 13, 'Power Slicer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 14, 'Iron Slicer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 15, 'Lighting Slicer' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 16, 'Mounted Samurai' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 17, 'Samurai General' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 18, 'Gokenin' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 19, 'Hatamoto' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 20, 'Daimyo' );
INSERT INTO titles (title_set_id, title_level_id, text) VALUES ( 6, 21, 'Shogun' );

