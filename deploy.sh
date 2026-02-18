#!/bin/bash
# Deploy Blog to Server and Update Sitemap
# Uploads generated blog and updates sitemap.xml

source "$(dirname "$0")/config.sh"

# Check if blog was generated
if [ ! -f "$OUTPUT_DIR/latest_blog.json" ]; then
    echo "❌ No blog to deploy. Run generate_blog.sh first."
    exit 1
fi

# Read blog metadata
FILENAME=$(grep '"filename"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
TITLE=$(grep '"title"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
BLOG_URL=$(grep '"url"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
SLUG=$(grep '"slug"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
CATEGORY=$(grep '"category"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
TODAY=$(date +%Y-%m-%d)
FEATURED_IMAGE="${SLUG}.jpg"

echo "📤 Deploying: $FILENAME"

# Upload featured image to server
echo "🖼️ Uploading featured image..."
if [ -f "$OUTPUT_DIR/$FEATURED_IMAGE" ]; then
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -P "$SSH_PORT" \
        "$OUTPUT_DIR/$FEATURED_IMAGE" \
        "${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}/images/"
    echo "✅ Featured image uploaded: $FEATURED_IMAGE"
else
    echo "⚠️ No featured image found"
fi

# Upload blog file to server
echo "📁 Uploading blog file..."
sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -P "$SSH_PORT" \
    "$OUTPUT_DIR/$FILENAME" \
    "${SSH_USER}@${SSH_HOST}:${BLOG_PATH}/"

if [ $? -ne 0 ]; then
    echo "❌ Upload failed!"
    exit 1
fi

echo "✅ Blog uploaded successfully"

# Update sitemap on server
echo "🗺️ Updating sitemap..."

# Create sitemap entry
SITEMAP_ENTRY="    <url>
        <loc>${BLOG_URL}</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.8</priority>
    </url>"

# Add entry to sitemap (before closing </urlset>)
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << REMOTECMD
# Backup current sitemap
cp ${SITEMAP_PATH} ${SITEMAP_PATH}.bak

# Check if URL already exists
if grep -q "${BLOG_URL}" ${SITEMAP_PATH}; then
    echo "URL already in sitemap, updating lastmod..."
    sed -i "/${FILENAME}/,/<\/url>/s/<lastmod>[^<]*<\/lastmod>/<lastmod>${TODAY}<\/lastmod>/" ${SITEMAP_PATH}
else
    echo "Adding new URL to sitemap..."
    # Insert before </urlset>
    sed -i "/<\/urlset>/i\\
    <url>\\
        <loc>${BLOG_URL}</loc>\\
        <lastmod>${TODAY}</lastmod>\\
        <changefreq>monthly</changefreq>\\
        <priority>0.8</priority>\\
    </url>" ${SITEMAP_PATH}
fi

echo "Sitemap updated!"
REMOTECMD

echo "✅ Sitemap updated"

# Update blog listing page (blog.html) - Add new blog card
echo "📝 Updating blog listing page..."

# Create blog card HTML
BLOG_CARD="<article class=\"blog-card\">
    <div class=\"blog-content\">
        <span class=\"blog-date\">${TODAY}</span>
        <h3><a href=\"blog/${FILENAME}\">${TITLE}</a></h3>
        <a href=\"blog/${FILENAME}\" class=\"read-more\">Read Article <i class=\"fas fa-arrow-right\"></i></a>
    </div>
</article>"

# Add to blog.html (after blog-grid opening div)
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << REMOTECMD2
cd ${REMOTE_PATH}

# Backup blog.html
cp blog.html blog.html.bak

# Check if blog already listed
if grep -q "${FILENAME}" blog.html; then
    echo "Blog already listed in blog.html"
else
    # Add new blog card with thumbnail after <div class="blog-grid">
    sed -i '/<div class="blog-grid">/a\
                <article class="blog-card fade-in">\
                    <div class="blog-image">\
                        <img src="images/${FEATURED_IMAGE}" alt="${TITLE} - Real Estate Digital Marketing Guide | LeadHorizon" loading="lazy">\
                        <span class="blog-category">${CATEGORY}</span>\
                    </div>\
                    <div class="blog-content">\
                        <h3><a href="blog/${FILENAME}">${TITLE}</a></h3>\
                        <p>Expert insights and strategies for real estate developers from LeadHorizon.</p>\
                        <a href="blog/${FILENAME}" class="blog-link">Read More <i class="fas fa-arrow-right"></i></a>\
                    </div>\
                </article>' blog.html
    echo "Added blog to listing with thumbnail"
fi
REMOTECMD2

echo "✅ Blog listing updated"
echo ""
echo "🎉 Deployment complete!"
echo "📄 Blog URL: $BLOG_URL"
