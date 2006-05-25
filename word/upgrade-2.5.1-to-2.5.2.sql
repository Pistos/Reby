CREATE OR REPLACE VIEW battle_winners AS
select
    battles.id AS battle_id, (
        select player_id
        from games, participations
        where
            games.id = participations.game_id
            and points_awarded is not null
            and games.battle_id = battles.id
        order by game_id desc
        limit 1
    ) as battle_winner
from
    battles
where
    battles.battle_mode = 'lms'
order by
    battles.id
;

CREATE OR REPLACE VIEW battle_participants AS
select distinct
    battles.id AS battle_id,
    participations.player_id
from
    battles, games, participations
where
    battles.battle_mode = 'lms'
    and games.battle_id = battles.id
    and games.id = participations.game_id
order by
    battles.id
;

CREATE OR REPLACE VIEW num_player_battle_participations AS
SELECT
    player_id,
    COUNT(*) AS num_participations
FROM
    battle_participants
GROUP BY
    player_id
;

CREATE OR REPLACE VIEW player_overall_lms_success AS
SELECT
    bp.player_id,
    (
        SELECT COUNT(*) FROM battle_winners AS bw
        WHERE bw.battle_winner = bp.player_id
    )::FLOAT / bp.num_participations AS win_rate
FROM
    num_player_battle_participations AS bp
;
