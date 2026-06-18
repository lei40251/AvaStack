// Package config 提供编排层运行配置的加载能力。
// 所有配置项均通过环境变量注入，并在 Load() 时填充默认值。
package config

import "os"

// Config 聚合编排层启动所需的所有外部依赖地址和服务参数。
type Config struct {
	Port          string // HTTP 监听端口，默认 8080
	ASRBaseURL    string // 语音识别服务地址
	TTSBaseURL    string // 语音合成服务地址
	AvatarBaseURL string // 数字人渲染服务地址
	LLMBaseURL    string // 大语言模型服务地址
	LiveKitWSURL  string // LiveKit WebSocket 信令地址
	SRSRTCBaseURL string // SRS RTC HTTP API 地址
}

// env 读取环境变量，若未设置则返回默认值。
func env(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

// Load 从环境变量构造 Config，每个字段均有生产可用的默认值。
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
