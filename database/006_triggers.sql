DROP TRIGGER IF EXISTS trg_users_set_anonymous_name ON users;
CREATE TRIGGER trg_users_set_anonymous_name
BEFORE INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION set_user_anonymous_name();

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_wishes_enforce_daily_limit ON wishes;
CREATE TRIGGER trg_wishes_enforce_daily_limit
BEFORE INSERT ON wishes
FOR EACH ROW
EXECUTE FUNCTION enforce_daily_wish_limit();

DROP TRIGGER IF EXISTS trg_wishes_set_updated_at ON wishes;
CREATE TRIGGER trg_wishes_set_updated_at
BEFORE UPDATE ON wishes
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_wishes_after_insert_patterns ON wishes;
CREATE TRIGGER trg_wishes_after_insert_patterns
AFTER INSERT ON wishes
FOR EACH ROW
EXECUTE FUNCTION handle_wish_insert();

DROP TRIGGER IF EXISTS trg_interactions_after_resonate ON interactions;
CREATE TRIGGER trg_interactions_after_resonate
AFTER INSERT ON interactions
FOR EACH ROW
WHEN (NEW.type = 'resonate')
EXECUTE FUNCTION handle_resonate_interaction();

DROP TRIGGER IF EXISTS trg_matches_validate_integrity ON matches;
CREATE TRIGGER trg_matches_validate_integrity
BEFORE INSERT OR UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION validate_match_integrity();

DROP TRIGGER IF EXISTS trg_matches_after_insert_notify ON matches;
CREATE TRIGGER trg_matches_after_insert_notify
AFTER INSERT ON matches
FOR EACH ROW
EXECUTE FUNCTION handle_match_notifications();

DROP TRIGGER IF EXISTS trg_messages_validate_sender ON messages;
CREATE TRIGGER trg_messages_validate_sender
BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION validate_message_sender();

DROP TRIGGER IF EXISTS trg_messages_touch_conversation ON messages;
CREATE TRIGGER trg_messages_touch_conversation
AFTER INSERT OR UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION touch_conversation_last_message();

DROP TRIGGER IF EXISTS trg_emotional_patterns_set_updated_at ON emotional_patterns;
CREATE TRIGGER trg_emotional_patterns_set_updated_at
BEFORE UPDATE ON emotional_patterns
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_aura_customizations_set_updated_at ON aura_customizations;
CREATE TRIGGER trg_aura_customizations_set_updated_at
BEFORE UPDATE ON aura_customizations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
