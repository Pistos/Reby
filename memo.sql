CREATE TABLE memos (
    id SERIAL NOT NULL PRIMARY KEY,
    sender VARCHAR( 128 ),
    recipient VARCHAR( 128 ),
    recipient_regexp VARCHAR( 128 ),
    time_sent TIMESTAMP NOT NULL DEFAULT NOW(),
    time_told TIMESTAMP,
    message VARCHAR( 4096 )
)