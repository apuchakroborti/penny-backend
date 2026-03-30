from django.contrib import admin

from api import models


class ReadOnlyViewAdmin(admin.ModelAdmin):
    def get_readonly_fields(self, request, obj=None):
        return [field.name for field in self.model._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def has_change_permission(self, request, obj=None):
        return request.method in ("GET", "HEAD", "OPTIONS")


@admin.register(models.User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("anonymous_name", "intent", "is_premium", "is_banned", "created_at")
    list_filter = ("intent", "is_premium", "is_banned")
    search_fields = ("anonymous_name", "current_mood")


@admin.register(models.UserTag)
class UserTagAdmin(admin.ModelAdmin):
    list_display = ("tag", "user", "created_at")
    search_fields = ("tag", "user__anonymous_name")


@admin.register(models.Wish)
class WishAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "emotion_label", "visibility", "is_moderated", "resonance_count", "created_at")
    list_filter = ("emotion_label", "visibility", "is_moderated", "used_ai_refinement")
    search_fields = ("content", "ai_refined_content", "user__anonymous_name")


@admin.register(models.WishTag)
class WishTagAdmin(admin.ModelAdmin):
    list_display = ("tag", "wish")
    search_fields = ("tag",)


@admin.register(models.WishReply)
class WishReplyAdmin(admin.ModelAdmin):
    list_display = ("id", "wish", "author_user", "parent_reply", "created_at")
    search_fields = ("content", "author_user__anonymous_name")


@admin.register(models.Interaction)
class InteractionAdmin(admin.ModelAdmin):
    list_display = ("actor_user", "target_wish", "type", "created_at")
    list_filter = ("type",)


@admin.register(models.Match)
class MatchAdmin(admin.ModelAdmin):
    list_display = ("id", "match_status", "similarity_score", "created_at", "expires_at")
    list_filter = ("match_status",)


@admin.register(models.Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ("id", "match", "is_active", "last_message_at", "created_at")
    list_filter = ("is_active", "identity_revealed_a", "identity_revealed_b")


@admin.register(models.Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ("id", "conversation", "sender_user", "ai_suggested", "is_deleted", "sent_at")
    list_filter = ("ai_suggested", "is_deleted")
    search_fields = ("content",)


@admin.register(models.EmotionalPattern)
class EmotionalPatternAdmin(admin.ModelAdmin):
    list_display = ("user", "dominant_emotion", "wish_count", "resonate_given", "resonate_received", "updated_at")


@admin.register(models.ModerationLog)
class ModerationLogAdmin(admin.ModelAdmin):
    list_display = ("id", "triggered_by", "action_taken", "reviewed_by_admin", "created_at")
    list_filter = ("triggered_by", "action_taken", "reviewed_by_admin")
    search_fields = ("reason",)


@admin.register(models.Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ("id", "reporter_user", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("reason",)


@admin.register(models.Block)
class BlockAdmin(admin.ModelAdmin):
    list_display = ("blocker_user", "blocked_user", "created_at")


@admin.register(models.Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("user", "type", "title", "is_read", "created_at")
    list_filter = ("type", "is_read")
    search_fields = ("title", "body")


@admin.register(models.Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ("user", "plan", "stripe_subscription_id", "started_at", "expires_at")
    list_filter = ("plan",)
    search_fields = ("stripe_subscription_id",)


@admin.register(models.AuraCustomization)
class AuraCustomizationAdmin(admin.ModelAdmin):
    list_display = ("user", "glow_color", "particle_style", "animation_speed", "updated_at")
    list_filter = ("particle_style", "animation_speed")


@admin.register(models.PublicWishFeed)
class PublicWishFeedAdmin(ReadOnlyViewAdmin):
    list_display = ("wish_id", "anonymous_name", "emotion_label", "resonance_count", "created_at")
    search_fields = ("anonymous_name", "display_content")


@admin.register(models.UserEmotionalSummary)
class UserEmotionalSummaryAdmin(ReadOnlyViewAdmin):
    list_display = ("anonymous_name", "intent", "has_active_premium", "dominant_emotion", "wish_count")
    search_fields = ("anonymous_name", "dominant_emotion")


@admin.register(models.ActiveMatch)
class ActiveMatchAdmin(ReadOnlyViewAdmin):
    list_display = ("id", "anonymous_name_a", "anonymous_name_b", "similarity_score", "conversation_active", "created_at")
    search_fields = ("anonymous_name_a", "anonymous_name_b")


@admin.register(models.MatchGraph)
class MatchGraphAdmin(ReadOnlyViewAdmin):
    list_display = ("id", "node_a_name", "node_b_name", "match_status", "similarity_score", "created_at")
    search_fields = ("node_a_name", "node_b_name")


@admin.register(models.AppUserToken)
class AppUserTokenAdmin(admin.ModelAdmin):
    list_display = ("user_id", "key", "created_at", "updated_at", "last_used_at")
    search_fields = ("user_id", "key")
