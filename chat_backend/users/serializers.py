from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Profile, Message
from django.db.models import Q

class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = ['profile_pic', 'is_online', 'last_seen']

class UserListSerializer(serializers.ModelSerializer):
    profile = ProfileSerializer(read_only=True)
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'profile', 'last_message', 'unread_count']

    def get_last_message(self, obj):
        last_msg = Message.objects.filter(
            (Q(sender=obj, receiver=self.context['request'].user) | 
             Q(sender=self.context['request'].user, receiver=obj))
        ).order_by('-timestamp').first()
        
        if last_msg:
            return {
                'content': last_msg.content,
                'timestamp': last_msg.timestamp
            }
        return None

    def get_unread_count(self, obj):
        return Message.objects.filter(
            sender=obj, 
            receiver=self.context['request'].user, 
            is_read=False
        ).count()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['username', 'email', 'password']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        Profile.objects.create(user=user) # Automatically create profile
        return user

class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ['id', 'sender', 'receiver', 'content', 'timestamp', 'is_delivered', 'is_read']
        read_only_fields = ['sender', 'is_delivered', 'is_read']
