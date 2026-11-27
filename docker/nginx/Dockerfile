FROM nginx:alpine

# Copy our custom Nginx configuration
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy Laravel public files into the Nginx container
COPY public/ /var/www/html/public/

# Link /storage URLs to the shared storage volume
RUN ln -sfn /var/www/html/storage/app/public /var/www/html/public/storage