
from django.contrib import admin
from django.urls import path, re_path
from django.urls import include
from django.views.generic import TemplateView
from django.conf import settings
from django.conf.urls.static import static

from drf_spectacular.views import SpectacularAPIView

urlpatterns = [
    path('api/', include('users.urls')),
    # Only keep the lightweight schema endpoint for Vercel
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
]

# Serve Flutter web app for all other routes (SPA routing)
urlpatterns += [
    re_path(r'^.*$', TemplateView.as_view(template_name='index.html')),
]

# Serve static files in development
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
