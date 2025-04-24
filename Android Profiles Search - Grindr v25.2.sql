/*
This query has been used and tested with Grindr for Android, v.25.2 

*/


WITH UniqueProfileIDs AS (
	SELECT profile_id
	FROM profile
	UNION
	SELECT profile_id
	FROM chat_conversation_participants
),
DeviceUser AS (
	SELECT participant_id AS profile_id
	FROM (
		SELECT SUBSTR(conversation_id, 1, INSTR(conversation_id, ':') - 1) AS participant_id
		FROM chat_conversation_participants
		WHERE INSTR(conversation_id, ':') > 0
		UNION
		SELECT SUBSTR(conversation_id, INSTR(conversation_id, ':') + 1) AS participant_id
		FROM chat_conversation_participants
		WHERE INSTR(conversation_id, ':') > 0
	)
	WHERE participant_id NOT IN (SELECT profile_id FROM chat_conversation_participants)
	GROUP BY participant_id
	ORDER BY COUNT(*) DESC
	LIMIT 1
),
ProfileDedup AS (
	SELECT
		profile_id,
		display_name,
		media_hash,
		about_me,
		facebook_id,
		twitter_id,
		instagram_id,
		verified_instagram_id
	FROM (
		SELECT
			profile_id,
			display_name,
			media_hash,
			about_me,
			facebook_id,
			twitter_id,
			instagram_id,
			verified_instagram_id,
			ROW_NUMBER() OVER (PARTITION BY profile_id ORDER BY display_name) AS rn
		FROM profile
	) WHERE rn = 1
),
ChatDedup AS (
	SELECT
		profile_id,
		name AS display_name,
		primary_media_hash AS media_hash,
		strftime('%Y-%m-%d %H:%M:%S', last_online / 1000, 'unixepoch') AS last_online
	FROM (
		SELECT
			ccp.profile_id,
			cc.name,
			ccp.primary_media_hash,
			ccp.last_online,
			ROW_NUMBER() OVER (PARTITION BY ccp.profile_id ORDER BY ccp.last_online DESC) AS rn
		FROM chat_conversation_participants ccp
		LEFT JOIN chat_conversations cc ON ccp.conversation_id = cc.conversation_id
	) WHERE rn = 1
),
PhotoAgg AS (
	SELECT
		profile_id,
		GROUP_CONCAT(order_ || ': ' || media_hash, '; ') AS additional_photos
	FROM profile_photo
	GROUP BY profile_id
	ORDER BY order_
)
SELECT
	u.profile_id AS "Profile ID",
	CASE
		WHEN u.profile_id = (SELECT profile_id FROM DeviceUser LIMIT 1)
		THEN COALESCE(p.display_name, c.display_name) || ' (Device User)'
		ELSE COALESCE(p.display_name, c.display_name)
	END AS "Display Name",
	COALESCE(p.media_hash, c.media_hash) AS "Media Hash",
	c.last_online AS "Last Online",
	p.about_me AS "About Me",
	TRIM(
		COALESCE('Facebook: ' || NULLIF(p.facebook_id, '') || ';', '') ||
		COALESCE('Twitter: ' || NULLIF(p.twitter_id, '') || ';', '') ||
		COALESCE('Instagram: ' || NULLIF(p.instagram_id, '') || ';', '') ||
		COALESCE('Verified Instagram: ' || NULLIF(p.verified_instagram_id, '') || ';', ''),
		';'
	) AS "Social Media",
	CASE WHEN b."profileID" IS NOT NULL THEN 'Yes' ELSE 'No' END AS "Is Banned",
	CASE WHEN bl."profileID" IS NOT NULL THEN 'Yes' ELSE 'No' END AS "Is Blocked",
	CASE WHEN p.profile_id IS NOT NULL THEN 'Profile Table' ELSE 'Chat Participants' END AS "Source",
	ph.additional_photos AS "Additional Photos"
FROM UniqueProfileIDs u
LEFT JOIN ProfileDedup p ON u.profile_id = p.profile_id
LEFT JOIN ChatDedup c ON u.profile_id = c.profile_id
LEFT JOIN banned b ON u.profile_id = b."profileID"
LEFT JOIN blocks bl ON u.profile_id = bl."profileID"
LEFT JOIN PhotoAgg ph ON u.profile_id = ph.profile_id
WHERE (p.profile_id IS NOT NULL OR c.profile_id IS NOT NULL)
  AND (p.profile_id IS NULL OR c.profile_id IS NULL)
ORDER BY CASE
	WHEN u.profile_id = (SELECT profile_id FROM DeviceUser LIMIT 1)
	THEN 0
	WHEN p.profile_id IS NOT NULL
	THEN 1
	ELSE 2
END;
