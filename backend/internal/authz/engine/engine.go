package engine

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
	"github.com/swiftai-erp/backend/internal/authz/models"
	"github.com/swiftai-erp/backend/internal/authz/repository"
)

// PermissionEngine is the core permission checking component.
// It resolves user roles (recursive), loads auth values, and evaluates
// whether a user has a specific auth object + activity + field values.
type PermissionEngine struct {
	roleRepo      *repository.RoleRepo
	authValueRepo *repository.AuthValueRepo
	authObjRepo   *repository.AuthObjectRepo
	rdb           *redis.Client

	// Cache for resolved role IDs per user
	roleCache *sync.Map
	// Cache for auth values by role set (keyed by role set hash)
	authValueCache *sync.Map
}

func New(roleRepo *repository.RoleRepo, authValueRepo *repository.AuthValueRepo,
	authObjRepo *repository.AuthObjectRepo, rdb *redis.Client) *PermissionEngine {
	return &PermissionEngine{
		roleRepo:       roleRepo,
		authValueRepo:  authValueRepo,
		authObjRepo:    authObjRepo,
		rdb:            rdb,
		roleCache:      &sync.Map{},
		authValueCache: &sync.Map{},
	}
}

// Check evaluates whether a user has permission for an auth object + activity.
// It returns detailed results including which role matched.
func (e *PermissionEngine) Check(ctx context.Context, req *models.PermissionCheckRequest) (*models.PermissionCheckResult, error) {
	userID := uuid.MustParse(req.UserID)

	// Phase 1: Get effective roles (with composite/derived expansion)
	roles, err := e.getEffectiveRoles(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get effective roles: %w", err)
	}
	if len(roles) == 0 {
		return &models.PermissionCheckResult{Granted: false}, nil
	}

	// Phase 2: Look up auth values for all roles
	roleIDs := make([]uuid.UUID, len(roles))
	for i, r := range roles {
		roleIDs[i] = r.ID
	}

	authValues, err := e.getAuthValuesForRoles(ctx, roleIDs)
	if err != nil {
		return nil, fmt.Errorf("get auth values: %w", err)
	}

	if len(authValues) == 0 {
		return &models.PermissionCheckResult{Granted: false}, nil
	}

	// Phase 3: Check each auth value
	// Build a map of object_code -> []RoleAuthValue for fast lookup
	objectAuthValues := make(map[string][]*models.RoleAuthValue)
	for _, av := range authValues {
		// We need the object code - look it up
		obj, err := e.authObjRepo.GetByID(ctx, av.AuthObjectID)
		if err != nil || obj == nil {
			continue
		}
		objectAuthValues[obj.ObjectCode] = append(objectAuthValues[obj.ObjectCode], av)
	}

	vals, ok := objectAuthValues[req.Object]
	if !ok {
		return &models.PermissionCheckResult{Granted: false}, nil
	}

	// Phase 4: Match activity and field values
	for _, av := range vals {
		if !e.matchActivity(av, req.Activity) {
			continue
		}

		if !e.matchFieldValues(av, req.Fields) {
			continue
		}

		// All checks passed — granted by this role
		roleID := av.RoleID.String()
		return &models.PermissionCheckResult{
			Granted:   true,
			MatchedBy: roleID,
		}, nil
	}

	return &models.PermissionCheckResult{Granted: false}, nil
}

// CheckSimple is a convenience wrapper for boolean checks (no field-level).
func (e *PermissionEngine) CheckSimple(ctx context.Context, userID, objectCode, activity string) (bool, error) {
	req := &models.PermissionCheckRequest{
		UserID:   userID,
		Object:   objectCode,
		Activity: activity,
		Fields:   nil,
	}
	result, err := e.Check(ctx, req)
	if err != nil {
		return false, err
	}
	return result.Granted, nil
}

// CheckField is a convenience wrapper with field values.
func (e *PermissionEngine) CheckField(ctx context.Context, userID, objectCode, activity string, fields map[string]string) (bool, error) {
	req := &models.PermissionCheckRequest{
		UserID:   userID,
		Object:   objectCode,
		Activity: activity,
		Fields:   fields,
	}
	result, err := e.Check(ctx, req)
	if err != nil {
		return false, err
	}
	return result.Granted, nil
}

// ---- Internal helpers ----

func (e *PermissionEngine) getEffectiveRoles(ctx context.Context, userID uuid.UUID) ([]*models.RoleMaster, error) {
	// Try Redis cache first
	cacheKey := fmt.Sprintf("swiftai:roles:%s", userID.String())
	if e.rdb != nil {
		exists, _ := e.rdb.Exists(ctx, cacheKey).Result()
		if exists > 0 {
			// Cache hit — return cached role IDs
			if cached, ok := e.roleCache.Load(cacheKey); ok {
				return cached.([]*models.RoleMaster), nil
			}
		}
	}

	// Load from DB
	roles, err := e.roleRepo.GetEffectiveRoles(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Cache in memory (with TTL via periodic invalidation)
	e.roleCache.Store(cacheKey, roles)

	// Set Redis cache with 5 minute TTL
	if e.rdb != nil {
		if err := e.rdb.Set(ctx, cacheKey, "1", 5*time.Minute).Err(); err != nil {
			log.Warn().Err(err).Msg("failed to set role cache")
		}
	}

	return roles, nil
}

func (e *PermissionEngine) getAuthValuesForRoles(ctx context.Context, roleIDs []uuid.UUID) ([]*models.RoleAuthValue, error) {
	// Generate a cache key from sorted role IDs
	key := authValuesCacheKey(roleIDs)

	// Check in-memory cache
	if cached, ok := e.authValueCache.Load(key); ok {
		return cached.([]*models.RoleAuthValue), nil
	}

	// Load from DB
	vals, err := e.authValueRepo.GetAuthValuesForRoleIDs(ctx, roleIDs)
	if err != nil {
		return nil, err
	}

	// Cache in memory
	e.authValueCache.Store(key, vals)

	return vals, nil
}

func (e *PermissionEngine) matchActivity(av *models.RoleAuthValue, activity string) bool {
	switch activity {
	case "create":
		return av.ActivityCreate
	case "read":
		return av.ActivityRead
	case "update":
		return av.ActivityUpdate
	case "delete":
		return av.ActivityDelete
	case "approve":
		return av.ActivityApprove
	case "print":
		return av.ActivityPrint
	case "transfer":
		return av.ActivityTransfer
	case "close":
		return av.ActivityClose
	case "manage":
		// Manage = any CRUD activity
		return av.ActivityCreate || av.ActivityRead || av.ActivityUpdate || av.ActivityDelete
	default:
		return false
	}
}

func (e *PermissionEngine) matchFieldValues(av *models.RoleAuthValue, reqFields map[string]string) bool {
	if len(av.FieldValues) == 0 && len(av.FieldRanges) == 0 {
		// No field restrictions needed — activity match is enough
		return true
	}

	if len(reqFields) == 0 {
		return false
	}

	for field := range av.FieldValues {
		if !fieldRestrictionMatches(av, field, reqFields[field]) {
			return false
		}
	}
	for field := range av.FieldRanges {
		if _, alreadyChecked := av.FieldValues[field]; alreadyChecked {
			continue
		}
		if !fieldRestrictionMatches(av, field, reqFields[field]) {
			return false
		}
	}
	return true

	for reqField, reqValue := range reqFields {
		// Check exact value match
		if allowed, ok := av.FieldValues[reqField]; ok && allowed == reqValue {
			continue
		}

		// Check range match
		if rangeVal, ok := av.FieldRanges[reqField]; ok {
			if reqValue >= rangeVal.From && reqValue <= rangeVal.To {
				continue
			}
		}

		// Check wildcard
		if wild, ok := av.FieldValues[reqField]; ok && wild == "*" {
			continue
		}

		// No match — field is not covered
		return false
	}

	return true
}

func fieldRestrictionMatches(av *models.RoleAuthValue, field, reqValue string) bool {
	reqValue = strings.TrimSpace(reqValue)
	if reqValue == "" {
		return false
	}

	if allowed, ok := av.FieldValues[field]; ok {
		allowed = strings.TrimSpace(allowed)
		if allowed == "*" {
			return true
		}
		for _, candidate := range strings.Split(allowed, ",") {
			if strings.TrimSpace(candidate) == reqValue {
				return true
			}
		}
	}

	if rangeVal, ok := av.FieldRanges[field]; ok {
		fromOK := rangeVal.From == "" || reqValue >= rangeVal.From
		toOK := rangeVal.To == "" || reqValue <= rangeVal.To
		return fromOK && toOK
	}

	return false
}

func (e *PermissionEngine) InvalidateUserCache(ctx context.Context, userID uuid.UUID) {
	cacheKey := fmt.Sprintf("swiftai:roles:%s", userID.String())
	e.roleCache.Delete(cacheKey)
	if e.rdb != nil {
		e.rdb.Del(ctx, cacheKey)
	}
}

func (e *PermissionEngine) InvalidateRoleCache(roleID uuid.UUID) {
	// Clear all auth value cache (simple approach: clear all)
	e.authValueCache = &sync.Map{}
}

// authValuesCacheKey creates a deterministic key from a set of role IDs.
func authValuesCacheKey(roleIDs []uuid.UUID) string {
	// Simple concatenation — fine for our use case
	parts := make([]string, 0, len(roleIDs))
	for _, id := range roleIDs {
		parts = append(parts, id.String())
	}
	sort.Strings(parts)
	return strings.Join(parts, ",")
}
