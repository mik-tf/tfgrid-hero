#!/usr/bin/env -S v -enable-globals -n -w -gc none -cc tcc -d use_openssl -no-skip-unused run

import freeflowuniverse.herolib.hero.heromodels
import freeflowuniverse.herolib.hero.db
import freeflowuniverse.herolib.core.redisclient
import time
import os

fn main() {
	// Start the server in a background thread with authentication disabled for testing
	spawn fn () ! {
		// Create Redis connection with authentication (both ports require password)
		mut redis_conn := redisclient.new('127.0.0.1:6379')!
		redis_password := os.getenv('REDIS_PASSWORD')
		if redis_password != '' {
			redis_conn.send_expect_ok(['AUTH', redis_password])!
		}

		heromodels.new(
			reset: true,
			name: 'test',
			redis: &redis_conn
		)!

		// Get domain from environment or use default
		domain_name := os.getenv('DOMAIN_NAME')
		enable_ssl := os.getenv('ENABLE_SSL') == 'true'

		// Set allowed origins based on domain and SSL settings
		mut allowed_origins := []string{}
		if domain_name != '' {
			protocol := if enable_ssl { 'https://' } else { 'http://' }
			allowed_origins = ['${protocol}${domain_name}']
		} else {
			// Fallback to localhost for development
			allowed_origins = ['http://localhost:5173']
		}

		heromodels.server_start(
			name:            'test'
			port:            8080
			auth_enabled:    false // Disable auth for testing
			cors_enabled:    true
			reset:           true
			allowed_origins: allowed_origins
		) or { panic('Failed to start HeroModels server: ${err}') }
	}()

	// Keep the main thread alive
	for {
		time.sleep(time.second)
	}
}