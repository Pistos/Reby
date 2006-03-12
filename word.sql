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
    consecutive_wins INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE games (
    id SERIAL PRIMARY KEY,
    word_id INTEGER NOT NULL REFERENCES words( id ),
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    winner INTEGER REFERENCES players( id ),
    points_awarded INTEGER
);

CREATE TABLE games_players (
    game_id INTEGER NOT NULL REFERENCES games( id ),
    player_id INTEGER NOT NULL REFERENCES players( id )
);

CREATE TABLE channels (
    id SERIAL PRIMARY KEY,
    name VARCHAR( 64 ) NOT NULL,
    current_word INTEGER NOT NULL DEFAULT 1 REFERENCES words( id )
);