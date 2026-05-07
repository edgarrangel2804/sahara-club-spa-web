# Deploy Script for Sahara Club Spa
# Run this script after setting up GitHub repository

echo "🚀 Preparing deployment to Vercel..."

# Build the Flutter web app
echo "📦 Building Flutter web app..."
flutter build web --release --web-renderer canvaskit

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"

    echo "📋 Next steps:"
    echo "1. Create a new repository on GitHub (https://github.com/new)"
    echo "2. Run these commands:"
    echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git"
    echo "   git branch -M main"
    echo "   git push -u origin main"
    echo ""
    echo "3. Go to Vercel (https://vercel.com)"
    echo "4. Import your GitHub repository"
    echo "5. Vercel will automatically detect Flutter and deploy"
    echo ""
    echo "6. Add your custom domain: saharclubspa.com"
    echo "   - Go to Project Settings > Domains"
    echo "   - Add saharclubspa.com and follow DNS instructions"
    echo ""
    echo "🎉 Your luxury wellness platform will be live at saharclubspa.com!"
else
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi