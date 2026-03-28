ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_own ON users;
CREATE POLICY users_select_own
ON users
FOR SELECT
USING (
  app_current_user_id() IS NOT NULL
  AND id = app_current_user_id()
);

DROP POLICY IF EXISTS users_insert_self ON users;
CREATE POLICY users_insert_self
ON users
FOR INSERT
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND id = app_current_user_id()
);

DROP POLICY IF EXISTS users_update_own ON users;
CREATE POLICY users_update_own
ON users
FOR UPDATE
USING (
  app_current_user_id() IS NOT NULL
  AND id = app_current_user_id()
)
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND id = app_current_user_id()
);

DROP POLICY IF EXISTS wishes_select_public_or_own ON wishes;
CREATE POLICY wishes_select_public_or_own
ON wishes
FOR SELECT
USING (
  app_current_user_id() IS NOT NULL
  AND (
    (visibility = 'public' AND NOT is_moderated)
    OR user_id = app_current_user_id()
  )
);

DROP POLICY IF EXISTS wishes_insert_own ON wishes;
CREATE POLICY wishes_insert_own
ON wishes
FOR INSERT
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
);

DROP POLICY IF EXISTS wishes_update_own ON wishes;
CREATE POLICY wishes_update_own
ON wishes
FOR UPDATE
USING (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
)
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
);

DROP POLICY IF EXISTS wishes_delete_own ON wishes;
CREATE POLICY wishes_delete_own
ON wishes
FOR DELETE
USING (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
);

DROP POLICY IF EXISTS messages_select_participants ON messages;
CREATE POLICY messages_select_participants
ON messages
FOR SELECT
USING (
  app_current_user_id() IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM conversations c
    JOIN matches m ON m.id = c.match_id
    WHERE c.id = messages.conversation_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
);

DROP POLICY IF EXISTS messages_insert_participants ON messages;
CREATE POLICY messages_insert_participants
ON messages
FOR INSERT
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND sender_user_id = app_current_user_id()
  AND EXISTS (
    SELECT 1
    FROM conversations c
    JOIN matches m ON m.id = c.match_id
    WHERE c.id = messages.conversation_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
);

DROP POLICY IF EXISTS messages_update_sender ON messages;
CREATE POLICY messages_update_sender
ON messages
FOR UPDATE
USING (
  app_current_user_id() IS NOT NULL
  AND sender_user_id = app_current_user_id()
  AND EXISTS (
    SELECT 1
    FROM conversations c
    JOIN matches m ON m.id = c.match_id
    WHERE c.id = messages.conversation_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
)
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND sender_user_id = app_current_user_id()
  AND EXISTS (
    SELECT 1
    FROM conversations c
    JOIN matches m ON m.id = c.match_id
    WHERE c.id = messages.conversation_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
);

DROP POLICY IF EXISTS notifications_select_own ON notifications;
CREATE POLICY notifications_select_own
ON notifications
FOR SELECT
USING (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
);

DROP POLICY IF EXISTS notifications_update_own ON notifications;
CREATE POLICY notifications_update_own
ON notifications
FOR UPDATE
USING (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
)
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND user_id = app_current_user_id()
);

DROP POLICY IF EXISTS conversations_select_participants ON conversations;
CREATE POLICY conversations_select_participants
ON conversations
FOR SELECT
USING (
  app_current_user_id() IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM matches m
    WHERE m.id = conversations.match_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
);

DROP POLICY IF EXISTS conversations_update_participants ON conversations;
CREATE POLICY conversations_update_participants
ON conversations
FOR UPDATE
USING (
  app_current_user_id() IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM matches m
    WHERE m.id = conversations.match_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
)
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM matches m
    WHERE m.id = conversations.match_id
      AND app_current_user_id() IN (m.user_id_a, m.user_id_b)
  )
);

DROP POLICY IF EXISTS blocks_select_own ON blocks;
CREATE POLICY blocks_select_own
ON blocks
FOR SELECT
USING (
  app_current_user_id() IS NOT NULL
  AND blocker_user_id = app_current_user_id()
);

DROP POLICY IF EXISTS blocks_insert_own ON blocks;
CREATE POLICY blocks_insert_own
ON blocks
FOR INSERT
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND blocker_user_id = app_current_user_id()
);

DROP POLICY IF EXISTS blocks_update_own ON blocks;
CREATE POLICY blocks_update_own
ON blocks
FOR UPDATE
USING (
  app_current_user_id() IS NOT NULL
  AND blocker_user_id = app_current_user_id()
)
WITH CHECK (
  app_current_user_id() IS NOT NULL
  AND blocker_user_id = app_current_user_id()
);

DROP POLICY IF EXISTS blocks_delete_own ON blocks;
CREATE POLICY blocks_delete_own
ON blocks
FOR DELETE
USING (
  app_current_user_id() IS NOT NULL
  AND blocker_user_id = app_current_user_id()
);
