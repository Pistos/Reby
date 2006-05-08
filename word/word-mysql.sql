DELIMITER //

CREATE PROCEDURE rebuild_battle_words()
BEGIN
    TRUNCATE battle_words;
    
    INSERT INTO battle_words
        SELECT id AS word_id
        FROM word_frequency
        WHERE times_used = 0
        ORDER BY random()
    ;

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
END//

DELIMITER ;

CREATE TRIGGER trigger_remove_battle_word
AFTER INSERT ON participations FOR EACH ROW
    DELETE FROM battle_words
    WHERE battle_words.word_id = (
        SELECT games.word_id
        FROM games
        WHERE games.id = NEW.game_id
    )
;

CREATE TRIGGER trigger_add_practice_word
BEFORE DELETE ON battle_words FOR EACH ROW
    INSERT INTO practice_words VALUES ( OLD.word_id )
;
