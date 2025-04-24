/*
This query has been used and tested with Grindr for Android, v.25.2 

*/



WITH parsed_convo AS (
	SELECT
		*,
		CAST(substr(conversation_id, 1, instr(conversation_id, ':') - 1) AS TEXT) AS user_a,
		CAST(substr(conversation_id, instr(conversation_id, ':') + 1) AS TEXT) AS user_b
	FROM chat_messages
),
adjusted_messages AS (
	SELECT
		message_id,
		CASE
			WHEN sender = user_a THEN user_a
			ELSE user_b
		END AS true_sender,
		CASE
			WHEN sender = user_a THEN user_b
			ELSE user_a
		END AS true_recipient,
		body,
		reply_to_body,
		conversation_id,
		timestamp,
		unread,
		type,
		reply_to_message_id
	FROM parsed_convo
),
named_messages AS (
	SELECT
		am.*,
		sp.display_name AS sender_name,
		rp.display_name AS recipient_name,
		cc.name AS convo_name
	FROM adjusted_messages am
	LEFT JOIN profile sp ON am.true_sender = sp.profile_id
	LEFT JOIN profile rp ON am.true_recipient = rp.profile_id
	LEFT JOIN chat_conversations cc ON am.conversation_id = cc.conversation_id
),
message_with_reactions AS (
	SELECT
		nm.*,
		GROUP_CONCAT(
			'Reaction type ''' || cr.reaction_type || ''' by ''' || cr.profile_id || ''' at ''' || 
			strftime('%Y-%m-%d %H:%M:%S', cr.timestamp / 1000, 'unixepoch') || '''', 
			'; '
		) AS reaction_info
	FROM named_messages nm
	LEFT JOIN chat_reactions cr ON nm.message_id = cr.target_message_id
	GROUP BY nm.message_id
)
SELECT
	CASE
		WHEN sender_name IS NOT NULL THEN sender_name
		WHEN recipient_name IS NOT NULL AND convo_name != recipient_name THEN convo_name
		ELSE true_sender
	END AS "Sender Display Name",

	CASE
		WHEN recipient_name IS NOT NULL THEN recipient_name
		WHEN sender_name IS NOT NULL AND convo_name != sender_name THEN convo_name
		ELSE true_recipient
	END AS "Recipient Display Name",

	type AS "Message Type",

	CASE
		WHEN json_extract(body, '$.text') IS NOT NULL THEN json_extract(body, '$.text')
		ELSE body
	END AS "Message Body",

	strftime('%Y-%m-%d %H:%M:%S', timestamp / 1000, 'unixepoch') AS "Timestamp",

	CASE
		WHEN unread = 1 THEN 'Unread'
		ELSE 'Read'
	END AS "Read Status",

	CASE
		WHEN reply_to_message_id IS NOT NULL THEN 'Yes'
		ELSE 'No'
	END AS "Is Reply",

	reply_to_message_id AS "Replied to Message ID",

	message_id AS "Message ID",

	conversation_id AS "Conversation ID",

	reaction_info AS "Reaction"

FROM message_with_reactions
ORDER BY conversation_id, timestamp ASC;
