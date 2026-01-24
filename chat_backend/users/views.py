from rest_framework import generics
from django.contrib.auth.models import User
from .models import Message
from .serializers import UserSerializer, UserListSerializer, MessageSerializer
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.db.models import Q
from .mqtt import publish_message

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = UserSerializer

class UserListView(generics.ListAPIView):
    serializer_class = UserListSerializer
    permission_classes = (IsAuthenticated,)

    def get_queryset(self):
        return User.objects.exclude(id=self.request.user.id)

class MessageListCreateView(generics.ListCreateAPIView):
    serializer_class = MessageSerializer
    permission_classes = (IsAuthenticated,)

    def get_queryset(self):
        
        other_user_id = self.request.query_params.get('user_id')
        
        if not other_user_id:
            return Message.objects.none()
        
        
        return Message.objects.filter(
            Q(sender=self.request.user, receiver_id=other_user_id) |
            Q(receiver=self.request.user, sender_id=other_user_id)
        ).order_by('timestamp')

    def perform_create(self, serializer):
        message = serializer.save(sender=self.request.user)
        
        # Publish to MQTT for offline notifications
        publish_message(message.receiver.id, {
            'sender': message.sender.username,
            'content': message.content,
            'timestamp': str(message.timestamp)
        })
