DROP TABLE titles;
DROP TABLE title_levels;
DROP TABLE title_sets;
DROP TABLE channels;
DROP TABLE games_players;
DROP TABLE games;
DROP TABLE players;
DROP TABLE words;

CREATE TABLE words (
    id SERIAL PRIMARY KEY,
    word VARCHAR( 64 ) NOT NULL UNIQUE,
    pos VARCHAR( 32 ) NOT NULL,
    etymology VARCHAR( 256 ) NOT NULL,
    num_syllables INTEGER NOT NULL,
    definition VARCHAR( 512 ) NOT NULL
);

CREATE TABLE players (
    id SERIAL PRIMARY KEY,
    nick VARCHAR( 64 ) NOT NULL UNIQUE,
    creation_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    consecutive_wins INTEGER NOT NULL DEFAULT 0,
    title_set_id INTEGER NOT NULL DEFAULT 0 REFERENCES title_sets( id ),
    warmup_points INTEGER DEFAULT 0,
    highest_rating INTEGER DEFAULT 2000,
    lowest_rating INTEGER DEFAULT 2000,
    money INTEGER DEFAULT 0
);

CREATE TABLE games (
    id SERIAL PRIMARY KEY,
    word_id INTEGER NOT NULL REFERENCES words( id ),
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    warmup_winner INTEGER REFERENCES players( id )
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
    name VARCHAR( 64 ) NOT NULL,
    current_word INTEGER NOT NULL DEFAULT 1 REFERENCES words( id )
);

CREATE TABLE title_sets (
    id SERIAL PRIMARY KEY,
    name VARCHAR( 64 ) NOT NULL UNIQUE
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
