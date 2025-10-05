import Foundation

struct Config {
    static let supabase = SupabaseConfig(
        url: "https://fyjejvboeopofqbvvatc.supabase.co",
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5amVqdmJvZW9wb2ZxYnZ2YXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwODMwMDIsImV4cCI6MjA3MDY1OTAwMn0.Od2OfMA3D9HpL_MKusXWkblDBDKHKZWQuKbCo9LE3oU"
    )
}

struct SupabaseConfig {
    let url: String
    let anonKey: String
}
