INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'sword3', '+3 Sword', 3, 3000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'bow3', '+3 Bow', 3, 3000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'staff3', '+3 Staff', 3, 3000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'mace3', '+3 Mace', 3, 3000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'dagger3', '+3 Dagger', 3, 3000 );
INSERT INTO weapons( code, name, modifier, price ) VALUES ( 'katana3', '+3 Katana', 3, 3000 );

INSERT INTO armours( code, name, modifier, price ) VALUES ( 'splint-armour', 'Splint Armour', -3, 3000 );

CREATE TABLE targettings (
    id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players( id ),
    target INTEGER NOT NULL REFERENCES players( id ),
    ordinal INTEGER NOT NULL,
    UNIQUE ( player_id, ordinal )
);
