package config

import "os"

type Config struct {
	Port          string
	ASRBaseURL    string
	TTSBaseURL    string
	AvatarBaseURL string
	LLMBaseURL    string
	LiveKitWSURL  string
	SRSRTCBaseURL string
}

func env(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func Load() Config {
	return Config{
		Port:          env("PORT", "8080"),
		ASRBaseURL:    env("ASR_BASE_URL", "http://localhost:8101"),
		TTSBaseURL:    env("TTS_BASE_URL", "http://localhost:8102"),
		AvatarBaseURL: env("AVATAR_BASE_URL", "http://localhost:8103"),
		LLMBaseURL:    env("LLM_BASE_URL", "http://localhost:8104"),
		LiveKitWSURL:  env("LIVEKIT_WS_URL", "ws://localhost:7880"),
		SRSRTCBaseURL: env("SRS_RTC_BASE_URL", "http://localhost:1985"),
	}
}

