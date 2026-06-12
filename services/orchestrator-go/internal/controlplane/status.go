package controlplane

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

func IsValidStatus(status string) bool {
	_, ok := allowedStatusTransitions[status]
	return ok
}

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

