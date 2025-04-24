/* Tested and works with Grindr for iOS 25.2 04/23/25
Profile search for profiles from chats and profile table*/

WITH DeviceUser AS (
    SELECT participant_id AS profile_id
    FROM (
        SELECT SUBSTR(ZCONVERSATIONID, 1, INSTR(ZCONVERSATIONID, ':') - 1) AS participant_id
        FROM ZINBOXCONVERSATIONENTITY
        WHERE INSTR(ZCONVERSATIONID, ':') > 0
        UNION ALL
        SELECT SUBSTR(ZCONVERSATIONID, INSTR(ZCONVERSATIONID, ':') + 1) AS participant_id
        FROM ZINBOXCONVERSATIONENTITY
        WHERE INSTR(ZCONVERSATIONID, ':') > 0
    )
    WHERE participant_id NOT IN (SELECT CAST(ZPROFILEID AS TEXT) FROM ZINBOXCONVERSATIONPARTICIPANTENTITY)
    GROUP BY participant_id
    HAVING COUNT(*) = (SELECT COUNT(*) FROM ZINBOXCONVERSATIONENTITY WHERE INSTR(ZCONVERSATIONID, ':') > 0)
),
AllProfiles AS (
    -- Profiles from ZPROFILEENTITY
    SELECT
        CAST(ZPROFILEID AS TEXT) AS profile_id,
        ZNAME AS username,
        NULL AS conversation_id,
        NULL AS last_message_time,
        NULL AS unread_count,
        ZDISTANCE AS distance_meters,
        ZPRIMARYMEDIAHASH AS media_hash,
        NULL AS z_pk,
        'Profile Table' AS source,
        ZABOUTME AS about_me
    FROM ZPROFILEENTITY
    UNION
    -- Profiles from conversations not in ZPROFILEENTITY
    SELECT
        CAST(ZINBOXCONVERSATIONPARTICIPANTENTITY.ZPROFILEID AS TEXT) AS profile_id,
        ZINBOXCONVERSATIONENTITY.ZNAME AS username,
        ZINBOXCONVERSATIONENTITY.ZCONVERSATIONID AS conversation_id,
        datetime('2001-01-01', ZINBOXCONVERSATIONENTITY.ZLASTMESSAGETIMESTAMP || ' seconds') AS last_message_time,
        ZINBOXCONVERSATIONENTITY.ZUNREADCOUNT AS unread_count,
        ZINBOXCONVERSATIONPARTICIPANTENTITY.ZRAWDISTANCE AS distance_meters,
        ZINBOXCONVERSATIONPARTICIPANTENTITY.ZPRIMARYMEDIAHASH AS media_hash,
        ZINBOXCONVERSATIONENTITY.Z_PK AS z_pk,
        'Chat Participants' AS source,
        NULL AS about_me
    FROM ZINBOXCONVERSATIONENTITY
    JOIN ZINBOXCONVERSATIONPARTICIPANTENTITY
        ON ZINBOXCONVERSATIONPARTICIPANTENTITY.ZINBOXCONVERSATION = ZINBOXCONVERSATIONENTITY.Z_PK
    WHERE CAST(ZINBOXCONVERSATIONPARTICIPANTENTITY.ZPROFILEID AS TEXT) NOT IN (
        SELECT CAST(ZPROFILEID AS TEXT) FROM ZPROFILEENTITY
    )
),
DedupedProfiles AS (
    SELECT
        profile_id,
        MAX(username) AS username,
        MAX(conversation_id) AS conversation_id,
        MAX(last_message_time) AS last_message_time,
        MAX(unread_count) AS unread_count,
        MAX(distance_meters) AS distance_meters,
        MAX(media_hash) AS media_hash,
        MAX(z_pk) AS z_pk,
        MAX(source) AS source,
        MAX(about_me) AS about_me
    FROM AllProfiles
    GROUP BY profile_id
)
SELECT
    CASE
        WHEN profile_id = (SELECT profile_id FROM DeviceUser LIMIT 1)
        THEN username || ' (Device User)'
        ELSE username
    END AS "Username",
    profile_id AS "Profile ID",
    conversation_id AS "Conversation ID",
    last_message_time AS "Last Message Time",
    unread_count AS "Unread Messages",
    distance_meters AS "Distance (Meters)",
    media_hash AS "Profile Media Hash",
    about_me AS "About Me",
	source AS "Source"
    
FROM DedupedProfiles
ORDER BY 
    CASE
        WHEN profile_id = (SELECT profile_id FROM DeviceUser LIMIT 1)
        THEN 0
        WHEN CAST(profile_id AS INTEGER) > 0
        THEN 1
        ELSE 2
    END,
    z_pk ASC;
