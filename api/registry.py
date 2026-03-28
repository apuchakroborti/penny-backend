from api import viewsets

API_ENDPOINTS = [
    {"prefix": "users", "basename": "user", "viewset": viewsets.UserViewSet, "description": "CRUD access to users."},
    {"prefix": "user-tags", "basename": "user-tag", "viewset": viewsets.UserTagViewSet, "description": "CRUD access to user tags."},
    {"prefix": "wishes", "basename": "wish", "viewset": viewsets.WishViewSet, "description": "CRUD access to wishes."},
    {"prefix": "wish-tags", "basename": "wish-tag", "viewset": viewsets.WishTagViewSet, "description": "CRUD access to wish tags."},
    {"prefix": "wish-replies", "basename": "wish-reply", "viewset": viewsets.WishReplyViewSet, "description": "CRUD access to public wish replies."},
    {"prefix": "interactions", "basename": "interaction", "viewset": viewsets.InteractionViewSet, "description": "CRUD access to wish interactions."},
    {"prefix": "matches", "basename": "match", "viewset": viewsets.MatchViewSet, "description": "CRUD access to matches."},
    {"prefix": "conversations", "basename": "conversation", "viewset": viewsets.ConversationViewSet, "description": "CRUD access to conversations."},
    {"prefix": "messages", "basename": "message", "viewset": viewsets.MessageViewSet, "description": "CRUD access to messages."},
    {"prefix": "emotional-patterns", "basename": "emotional-pattern", "viewset": viewsets.EmotionalPatternViewSet, "description": "CRUD access to emotional pattern rollups."},
    {"prefix": "moderation-logs", "basename": "moderation-log", "viewset": viewsets.ModerationLogViewSet, "description": "CRUD access to moderation logs."},
    {"prefix": "reports", "basename": "report", "viewset": viewsets.ReportViewSet, "description": "CRUD access to reports."},
    {"prefix": "blocks", "basename": "block", "viewset": viewsets.BlockViewSet, "description": "CRUD access to blocks."},
    {"prefix": "notifications", "basename": "notification", "viewset": viewsets.NotificationViewSet, "description": "CRUD access to notifications."},
    {"prefix": "subscriptions", "basename": "subscription", "viewset": viewsets.SubscriptionViewSet, "description": "CRUD access to subscriptions."},
    {"prefix": "aura-customizations", "basename": "aura-customization", "viewset": viewsets.AuraCustomizationViewSet, "description": "CRUD access to aura customizations."},
    {"prefix": "views/public-wish-feed", "basename": "public-wish-feed", "viewset": viewsets.PublicWishFeedViewSet, "description": "Read-only access to v_public_wish_feed."},
    {"prefix": "views/user-emotional-summary", "basename": "user-emotional-summary", "viewset": viewsets.UserEmotionalSummaryViewSet, "description": "Read-only access to v_user_emotional_summary."},
    {"prefix": "views/active-matches", "basename": "active-match", "viewset": viewsets.ActiveMatchViewSet, "description": "Read-only access to v_active_matches."},
    {"prefix": "views/match-graph", "basename": "match-graph", "viewset": viewsets.MatchGraphViewSet, "description": "Read-only access to v_match_graph."},
]
