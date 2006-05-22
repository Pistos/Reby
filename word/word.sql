DROP TABLE battle_words;
DROP TABLE practice_words;
DROP TABLE equipment;
DROP TABLE items;
DROP TABLE titles;
DROP TABLE title_levels;
DROP TABLE title_sets;
DROP TABLE channels;
DROP TABLE games_players;
DROP TABLE games;
DROP TABLE players;
DROP TABLE words;

CREATE TABLE title_sets (
    id SERIAL PRIMARY KEY,
    name VARCHAR( 64 ) NOT NULL UNIQUE,
    default_weapon_id INTEGER NOT NULL REFERENCES weapons( id )
);

CREATE TABLE players (
    id SERIAL PRIMARY KEY,
    nick VARCHAR( 64 ) NOT NULL UNIQUE,
    creation_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    title_set_id INTEGER NOT NULL DEFAULT 0 REFERENCES title_sets( id ),
    warmup_points INTEGER DEFAULT 0,
    money INTEGER DEFAULT 0
);

CREATE TABLE words (
    id SERIAL PRIMARY KEY,
    word VARCHAR( 64 ) NOT NULL UNIQUE,
    pos VARCHAR( 32 ) NOT NULL,
    etymology VARCHAR( 256 ) NOT NULL,
    num_syllables INTEGER NOT NULL,
    definition VARCHAR( 512 ) NOT NULL,
    suggester INTEGER REFERENCES players( id )
);

CREATE TABLE battles (
    id SERIAL PRIMARY KEY,
    starter INTEGER NOT NULL REFERENCES players( id ),
    battle_mode VARCHAR( 16 ) NOT NULL
);

CREATE TABLE games (
    id SERIAL PRIMARY KEY,
    word_id INTEGER NOT NULL REFERENCES words( id ),
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    warmup_winner INTEGER REFERENCES players( id ),
    battle_id INTEGER REFERENCES battles( id )
);

CREATE TABLE participations (
    id SERIAL PRIMARY KEY,
    game_id INTEGER NOT NULL REFERENCES games( id ),
    player_id INTEGER NOT NULL REFERENCES players( id ),
    points_awarded INTEGER,
    team VARCHAR( 32 ) NOT NULL
);

CREATE TABLE channels (
    id SERIAL PRIMARY KEY,
    name VARCHAR( 64 ) NOT NULL
);

CREATE TABLE title_levels (
    id INTEGER PRIMARY KEY,
    points INTEGER NOT NULL
);

CREATE TABLE titles (
    id SERIAL PRIMARY KEY,
    title_set_id INTEGER NOT NULL REFERENCES title_sets( id ),
    title_level_id INTEGER NOT NULL REFERENCES title_levels( id ),
    text VARCHAR( 128 ) NOT NULL,
    UNIQUE( title_set_id, text )
);

CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    code VARCHAR( 32 ) NOT NULL UNIQUE,
    name VARCHAR( 64 ) NOT NULL UNIQUE,
    price INTEGER NOT NULL,
    ownership_limit INTEGER NOT NULL DEFAULT 1
);
INSERT INTO items (code, name, price) VALUES ( 'glass-shield', 'Glass Shield', 300 );

CREATE TABLE equipment (
    id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players( id ),
    item_id INTEGER NOT NULL REFERENCES items( id ),
    equipped BOOLEAN NOT NULL DEFAULT FALSE
);

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

CREATE TABLE practice_words (
    word_id INTEGER NOT NULL REFERENCES words( id )
);
CREATE TABLE battle_words (
    word_id INTEGER NOT NULL REFERENCES words( id )
);

CREATE OR REPLACE VIEW word_frequency AS
SELECT
    words.id,
    (
        SELECT count(*) AS count
        FROM games
        WHERE games.word_id = words.id
            AND games.warmup_winner IS NULL
    ) AS times_used
FROM words
GROUP BY words.id
;

CREATE OR REPLACE VIEW num_participants AS
SELECT
    game_id,
    count(*) AS num_participants
FROM
    participations
GROUP BY
    game_id
ORDER BY
    game_id;
    
CREATE OR REPLACE VIEW game_size_frequencies AS
SELECT
    p.player_id,
    n.num_participants,
    count(*) AS num_games
FROM
    participations p,
    num_participants n
WHERE
    p.game_id = n.game_id
GROUP BY
    p.player_id,
    n.num_participants
;
    
CREATE OR REPLACE FUNCTION rebuild_battle_words()
    RETURNS VOID
    LANGUAGE 'plpgsql'
    AS '
BEGIN
    TRUNCATE battle_words;
    
    RAISE NOTICE ''Filling battle_words...'';
    
    INSERT INTO battle_words
        SELECT id AS word_id
        FROM word_frequency
        WHERE times_used = 0
        ORDER BY random()
    ;

    RAISE NOTICE ''Filling practice_words...'';
    
    TRUNCATE practice_words;
    
    INSERT INTO practice_words
        SELECT id AS word_id
        FROM words
        WHERE NOT EXISTS (
            SELECT 1
            FROM battle_words
            WHERE battle_words.word_id = words.id
        )
    ;
    
    RETURN;
END;
';

CREATE OR REPLACE RULE rule_remove_battle_word AS
ON INSERT TO participations DO
    DELETE FROM battle_words
    WHERE battle_words.word_id = (
        SELECT games.word_id
        FROM games
        WHERE games.id = NEW.game_id
    )
;

CREATE OR REPLACE RULE rule_add_practice_word AS
ON DELETE TO battle_words DO
    INSERT INTO practice_words VALUES ( OLD.word_id )
;
