import uuid
import secrets

from django.contrib.postgres.fields import ArrayField
from django.db import models
from pgvector.django import VectorField


class UserIntent(models.TextChoices):
    CONNECT = "connect", "Connect"
    EXPRESS = "express", "Express"
    EXPLORE = "explore", "Explore"


class WishEmotion(models.TextChoices):
    SADNESS = "sadness", "Sadness"
    LOVE = "love", "Love"
    CURIOSITY = "curiosity", "Curiosity"
    ANXIETY = "anxiety", "Anxiety"
    JOY = "joy", "Joy"
    ANGER = "anger", "Anger"
    NEUTRAL = "neutral", "Neutral"


class WishVisibility(models.TextChoices):
    PUBLIC = "public", "Public"
    ARCHIVED = "archived", "Archived"
    DELETED = "deleted", "Deleted"


class InteractionType(models.TextChoices):
    RESONATE = "resonate", "Resonate"
    REFLECT = "reflect", "Reflect"
    RESPOND = "respond", "Respond"
    DIVE_DEEPER = "dive_deeper", "Dive Deeper"


class MatchStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    OPENED = "opened", "Opened"
    REJECTED = "rejected", "Rejected"
    EXPIRED = "expired", "Expired"


class ModerationTrigger(models.TextChoices):
    AI = "ai", "AI"
    USER_REPORT = "user_report", "User Report"
    ADMIN = "admin", "Admin"


class ModerationAction(models.TextChoices):
    WARNED = "warned", "Warned"
    REMOVED = "removed", "Removed"
    REVIEWED = "reviewed", "Reviewed"
    CLEARED = "cleared", "Cleared"


class ReportStatus(models.TextChoices):
    OPEN = "open", "Open"
    RESOLVED = "resolved", "Resolved"
    DISMISSED = "dismissed", "Dismissed"


class NotificationType(models.TextChoices):
    RESONANCE = "resonance", "Resonance"
    WISH_REPLY = "wish_reply", "Wish Reply"
    WISH_REPLY_REPLY = "wish_reply_reply", "Wish Reply Reply"
    NEW_MATCH = "new_match", "New Match"
    MESSAGE = "message", "Message"
    REVEAL_REQUEST = "reveal_request", "Reveal Request"
    SYSTEM = "system", "System"


class SubscriptionPlan(models.TextChoices):
    FREE = "free", "Free"
    PREMIUM = "premium", "Premium"


class ParticleStyle(models.TextChoices):
    DUST = "dust", "Dust"
    SPARKLE = "sparkle", "Sparkle"
    RIPPLE = "ripple", "Ripple"
    EMBER = "ember", "Ember"


class AnimationSpeed(models.TextChoices):
    SLOW = "slow", "Slow"
    MEDIUM = "medium", "Medium"
    FAST = "fast", "Fast"


class UnmanagedModel(models.Model):
    class Meta:
        abstract = True
        managed = False


class User(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    anonymous_name = models.TextField(unique=True)
    email_hash = models.BinaryField(unique=True)
    password_hash = models.TextField()
    intent = models.CharField(max_length=20, choices=UserIntent.choices)
    current_mood = models.TextField(blank=True, null=True)
    is_premium = models.BooleanField(default=False)
    premium_expires_at = models.DateTimeField(blank=True, null=True)
    is_banned = models.BooleanField(default=False)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "users"
        ordering = ["-created_at"]

    def __str__(self):
        return self.anonymous_name


class UserTag(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="user_tags")
    tag = models.TextField()
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "user_tags"
        ordering = ["tag"]

    def __str__(self):
        return f"{self.user_id}:{self.tag}"


class Wish(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.RESTRICT, related_name="wishes")
    content = models.TextField()
    ai_refined_content = models.TextField(blank=True, null=True)
    used_ai_refinement = models.BooleanField(default=False)
    emotion_label = models.CharField(max_length=20, choices=WishEmotion.choices)
    emotion_score = models.FloatField()
    embedding = VectorField(dimensions=1536, blank=True, null=True)
    visibility = models.CharField(max_length=20, choices=WishVisibility.choices, default=WishVisibility.PUBLIC)
    is_moderated = models.BooleanField(default=False)
    moderation_flag = models.TextField(blank=True, null=True)
    resonance_count = models.IntegerField(default=0)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "wishes"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user_id}:{self.emotion_label}"


class WishTag(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wish = models.ForeignKey(Wish, on_delete=models.CASCADE, related_name="wish_tags")
    tag = models.TextField()

    class Meta(UnmanagedModel.Meta):
        db_table = "wish_tags"
        ordering = ["tag"]

    def __str__(self):
        return f"{self.wish_id}:{self.tag}"


class WishReply(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wish = models.ForeignKey(Wish, on_delete=models.CASCADE, related_name="wish_replies")
    author_user = models.ForeignKey(User, on_delete=models.RESTRICT, related_name="wish_replies")
    parent_reply = models.ForeignKey("self", on_delete=models.CASCADE, related_name="child_replies", blank=True, null=True)
    content = models.TextField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "wish_replies"
        ordering = ["created_at", "id"]

    def __str__(self):
        return str(self.id)


class Interaction(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor_user = models.ForeignKey(User, on_delete=models.RESTRICT, related_name="interactions_made")
    target_wish = models.ForeignKey(Wish, on_delete=models.CASCADE, related_name="interactions_received")
    type = models.CharField(max_length=20, choices=InteractionType.choices)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "interactions"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.actor_user_id}:{self.type}"


class Match(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_id_a = models.UUIDField()
    user_id_b = models.UUIDField()
    wish_id_a = models.UUIDField()
    wish_id_b = models.UUIDField()
    similarity_score = models.FloatField()
    shared_themes = ArrayField(models.TextField(), default=list)
    match_status = models.CharField(max_length=20, choices=MatchStatus.choices, default=MatchStatus.PENDING)
    revealed_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "matches"
        ordering = ["-created_at"]

    def __str__(self):
        return str(self.id)


class Conversation(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    match = models.OneToOneField(Match, on_delete=models.CASCADE, related_name="conversation")
    identity_revealed_a = models.BooleanField(default=False)
    identity_revealed_b = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    last_message_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "conversations"
        ordering = ["-created_at"]

    def __str__(self):
        return str(self.id)


class Message(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    sender_user = models.ForeignKey(User, on_delete=models.RESTRICT, related_name="messages_sent")
    content = models.TextField()
    ai_suggested = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    sent_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "messages"
        ordering = ["-sent_at"]

    def __str__(self):
        return str(self.id)


class EmotionalPattern(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="emotional_pattern")
    dominant_emotion = models.TextField(blank=True, null=True)
    emotion_distribution = models.JSONField(default=dict)
    top_themes = ArrayField(models.TextField(), default=list)
    wish_count = models.IntegerField(default=0)
    resonate_given = models.IntegerField(default=0)
    resonate_received = models.IntegerField(default=0)
    last_analyzed_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "emotional_patterns"
        ordering = ["-updated_at"]

    def __str__(self):
        return str(self.user_id)


class ModerationLog(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wish = models.ForeignKey(Wish, on_delete=models.SET_NULL, related_name="moderation_logs", blank=True, null=True)
    message = models.ForeignKey(Message, on_delete=models.SET_NULL, related_name="moderation_logs", blank=True, null=True)
    triggered_by = models.CharField(max_length=20, choices=ModerationTrigger.choices)
    reason = models.TextField()
    action_taken = models.CharField(max_length=20, choices=ModerationAction.choices)
    reviewed_by_admin = models.BooleanField(default=False)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "moderation_logs"
        ordering = ["-created_at"]

    def __str__(self):
        return str(self.id)


class Report(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter_user = models.ForeignKey(User, on_delete=models.RESTRICT, related_name="reports_filed")
    reported_user = models.ForeignKey(User, on_delete=models.SET_NULL, related_name="reports_received", blank=True, null=True)
    reported_wish = models.ForeignKey(Wish, on_delete=models.SET_NULL, related_name="reports", blank=True, null=True)
    reported_message = models.ForeignKey(Message, on_delete=models.SET_NULL, related_name="reports", blank=True, null=True)
    reason = models.TextField()
    status = models.CharField(max_length=20, choices=ReportStatus.choices, default=ReportStatus.OPEN)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "reports"
        ordering = ["-created_at"]

    def __str__(self):
        return str(self.id)


class Block(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    blocker_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="blocks_created")
    blocked_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="blocks_received")
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "blocks"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.blocker_user_id}->{self.blocked_user_id}"


class Notification(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    type = models.CharField(max_length=20, choices=NotificationType.choices)
    title = models.TextField()
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    related_entity_id = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "notifications"
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


class Subscription(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="subscriptions")
    plan = models.CharField(max_length=20, choices=SubscriptionPlan.choices)
    feature_flags = models.JSONField(default=dict)
    stripe_subscription_id = models.TextField(blank=True, null=True)
    started_at = models.DateTimeField()
    expires_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "subscriptions"
        ordering = ["-created_at"]

    def __str__(self):
        return str(self.id)


class AuraCustomization(UnmanagedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="aura_customization")
    glow_color = models.TextField()
    particle_style = models.CharField(max_length=20, choices=ParticleStyle.choices)
    animation_speed = models.CharField(max_length=20, choices=AnimationSpeed.choices)
    updated_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "aura_customizations"
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user_id}:{self.glow_color}"


class PublicWishFeed(UnmanagedModel):
    wish_id = models.UUIDField(primary_key=True)
    anonymous_name = models.TextField()
    display_content = models.TextField()
    emotion_label = models.CharField(max_length=20, choices=WishEmotion.choices)
    emotion_score = models.FloatField()
    resonance_count = models.IntegerField()
    tags = ArrayField(models.TextField(), default=list)
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "v_public_wish_feed"
        ordering = ["-created_at"]


class UserEmotionalSummary(UnmanagedModel):
    user_id = models.UUIDField(primary_key=True)
    anonymous_name = models.TextField()
    intent = models.CharField(max_length=20, choices=UserIntent.choices)
    current_mood = models.TextField(blank=True, null=True)
    has_active_premium = models.BooleanField()
    dominant_emotion = models.TextField(blank=True, null=True)
    emotion_distribution = models.JSONField(default=dict)
    top_themes = ArrayField(models.TextField(), default=list)
    wish_count = models.IntegerField()
    resonate_given = models.IntegerField()
    resonate_received = models.IntegerField()
    last_analyzed_at = models.DateTimeField(blank=True, null=True)

    class Meta(UnmanagedModel.Meta):
        db_table = "v_user_emotional_summary"
        ordering = ["anonymous_name"]


class ActiveMatch(UnmanagedModel):
    match_id = models.UUIDField(primary_key=True)
    anonymous_name_a = models.TextField()
    anonymous_name_b = models.TextField()
    similarity_score = models.FloatField()
    shared_themes = ArrayField(models.TextField(), default=list)
    revealed_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField()
    conversation_id = models.UUIDField(blank=True, null=True)
    conversation_active = models.BooleanField(blank=True, null=True)
    identity_revealed_a = models.BooleanField(blank=True, null=True)
    identity_revealed_b = models.BooleanField(blank=True, null=True)
    last_message_at = models.DateTimeField(blank=True, null=True)

    class Meta(UnmanagedModel.Meta):
        db_table = "v_active_matches"
        ordering = ["-created_at"]


class MatchGraph(UnmanagedModel):
    match_id = models.UUIDField(primary_key=True)
    match_status = models.CharField(max_length=20, choices=MatchStatus.choices)
    similarity_score = models.FloatField()
    shared_themes = ArrayField(models.TextField(), default=list)
    node_a_user_id = models.UUIDField()
    node_a_name = models.TextField()
    node_b_user_id = models.UUIDField()
    node_b_name = models.TextField()
    created_at = models.DateTimeField()

    class Meta(UnmanagedModel.Meta):
        db_table = "v_match_graph"
        ordering = ["-created_at"]


class AppUserToken(models.Model):
    key = models.CharField(max_length=64, primary_key=True, editable=False)
    user_id = models.UUIDField(unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_used_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user_id}:{self.key[:8]}"

    def save(self, *args, **kwargs):
        if not self.key:
            self.key = secrets.token_hex(20)
        super().save(*args, **kwargs)
