from django.urls import path
from .views import RegisterView, UserListView
from rest_framework.authtoken.views import obtain_auth_token 

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', obtain_auth_token, name='login'),
    path('users/', UserListView.as_view(), name='user-list'),
]