from rest_framework import generics
from django.contrib.auth.models import User
from .serializers import UserSerializer, UserListSerializer
from rest_framework.permissions import AllowAny, IsAuthenticated

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = UserSerializer

class UserListView(generics.ListAPIView):
    serializer_class = UserListSerializer
    permission_classes = (IsAuthenticated,)

    def get_queryset(self):
        return User.objects.exclude(id=self.request.user.id)
