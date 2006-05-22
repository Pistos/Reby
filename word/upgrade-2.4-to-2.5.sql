CREATE TABLE weapons (
    id SERIAL PRIMARY KEY,
    code VARCHAR( 32 ) NOT NULL UNIQUE,
    name VARCHAR( 64 ) NOT NULL UNIQUE,
    price INTEGER NOT NULL,
    modifier INTEGER NOT NULL
);
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'sword0', 'Sword', 0, 50 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'bow0', 'Bow', 0, 50 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'staff0', 'Staff', 0, 50 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'mace0', 'Mace', 0, 50 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'cluebat0', 'Clue Bat', 0, 0 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'dagger0', 'Dagger', 0, 50 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'katana0', 'Katana', 0, 50 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'sword1', '+1 Sword', 1, 1000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'bow1', '+1 Bow', 1, 1000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'staff1', '+1 Staff', 1, 1000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'mace1', '+1 Mace', 1, 1000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'dagger1', '+1 Dagger', 1, 1000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'katana1', '+1 Katana', 1, 1000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'sword2', '+2 Sword', 2, 2000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'bow2', '+2 Bow', 2, 2000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'staff2', '+2 Staff', 2, 2000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'mace2', '+2 Mace', 2, 2000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'dagger2', '+2 Dagger', 2, 2000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'katana2', '+2 Katana', 2, 2000 );

CREATE TABLE armaments (
    id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players( id ),
    weapon_id INTEGER NOT NULL REFERENCES weapons( id )
);

CREATE TABLE armours (
    id SERIAL PRIMARY KEY,
    code VARCHAR( 32 ) NOT NULL UNIQUE,
    name VARCHAR( 64 ) NOT NULL UNIQUE,
    price INTEGER NOT NULL,
    modifier INTEGER NOT NULL
);
INSERT INTO armours( code, name, modifier, price ) VALUES ( 'cloth-armour', 'Cloth Armour', 0, 50 );
INSERT INTO armours( code, name, modifier, price ) VALUES ( 'leather-armour', 'Leather Armour', -1, 1000 );
INSERT INTO armours( code, name, modifier, price ) VALUES ( 'chain-armour', 'Chain Armour', -2, 2000 );

CREATE TABLE protections (
    id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players( id ),
    armour_id INTEGER NOT NULL REFERENCES weapons( id )
);

ALTER TABLE title_sets ADD COLUMN default_weapon_id INTEGER NOT NULL DEFAULT 5 REFERENCES weapons( id );

update title_sets set default_weapon_id = 1 where id = 1;
update title_sets set default_weapon_id = 2 where id = 2;
update title_sets set default_weapon_id = 6 where id = 3;
update title_sets set default_weapon_id = 3 where id = 4;
update title_sets set default_weapon_id = 4 where id = 5;
update title_sets set default_weapon_id = 7 where id = 6;

insert into armaments (
    player_id, weapon_id
) select
    players.id, title_sets.default_weapon_id
from
    players, title_sets
where
    players.title_set_id = title_sets.id
    and not exists (
        select 1 from armaments where armaments.player_id = players.id limit 1
    )
;