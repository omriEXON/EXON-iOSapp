// Config.swift
import Foundation

struct Config {
    struct Supabase {
        static let url = "https://fyjejvboeopofqbvvatc.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5amVqdmJvZW9wb2ZxYnZ2YXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwODMwMDIsImV4cCI6MjA3MDY1OTAwMn0.Od2OfMA3D9HpL_MKusXWkblDBDKHKZWQuKbCo9LE3oU"
    }
    
    struct Support {
        static let whatsappNumber = "972557207138"
        static let email = "help@exongames.co.il"
    }
    
    struct Shopify {
        static let allowedOrigins = [
            "https://exongames.co.il",
            "https://exon-israel.myshopify.com"
        ]
    }
}
