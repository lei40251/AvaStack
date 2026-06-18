package controlplane

// allowedStatusTransitions 定义会话状态的合法迁移规则。
// 状态流转路径：created → ready → active → closed
//   - closed 是终态，不可再迁移至其他状态
//   - 同状态迁移（from == to）始终允许
var allowedStatusTransitions = map[string]map[string]struct{}{
	"created": {
		"ready":  {},
		"closed": {},
	},
	"ready": {
		"active": {},
		"closed": {},
	},
	"active": {
		"closed": {},
	},
	"closed": {},
}

// IsValidStatus 检查给定的状态值是否为系统中定义的合法状态。
func IsValidStatus(status string) bool {
	_, ok := allowedStatusTransitions[status]
	return ok
}

// CanTransitStatus 检查从 from 状态迁移到 to 状态是否合法。
// 同状态迁移视为合法（幂等）。
func CanTransitStatus(from, to string) bool {
	if from == to {
		return true
	}
	targets, ok := allowedStatusTransitions[from]
	if !ok {
		return false
	}
	_, ok = targets[to]
	return ok
}
