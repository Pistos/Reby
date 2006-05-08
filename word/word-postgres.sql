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
