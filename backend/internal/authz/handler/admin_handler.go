package handler

import (
	"errors"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/rs/zerolog/log"
	models "github.com/swiftai-erp/backend/internal/authz/models"
	"github.com/swiftai-erp/backend/internal/authz/repository"
	"github.com/swiftai-erp/backend/pkg/response"
	"golang.org/x/crypto/bcrypt"
)

type AdminHandler struct {
	authObjRepo *repository.AuthObjectRepo
	roleRepo    *repository.RoleRepo
	authValRepo *repository.AuthValueRepo
	userRepo    *repository.UserRepo
}

func NewAdminHandler(
	authObjRepo *repository.AuthObjectRepo,
	roleRepo *repository.RoleRepo,
	authValRepo *repository.AuthValueRepo,
	userRepo *repository.UserRepo,
) *AdminHandler {
	return &AdminHandler{
		authObjRepo: authObjRepo,
		roleRepo:    roleRepo,
		authValRepo: authValRepo,
		userRepo:    userRepo,
	}
}

// ==================== Users ====================

type createUserReq struct {
	Email        string   `json:"email" binding:"required,email"`
	Password     string   `json:"password" binding:"required,min=8"`
	DisplayName  string   `json:"display_name" binding:"required"`
	Phone        string   `json:"phone"`
	AvatarURL    string   `json:"avatar_url"`
	IsActive     *bool    `json:"is_active"`
	IsMFAEnabled bool     `json:"is_mfa_enabled"`
	RoleIDs      []string `json:"role_ids"`
}

type updateUserReq struct {
	Email        string `json:"email" binding:"required,email"`
	DisplayName  string `json:"display_name" binding:"required"`
	Phone        string `json:"phone"`
	AvatarURL    string `json:"avatar_url"`
	IsActive     bool   `json:"is_active"`
	IsMFAEnabled bool   `json:"is_mfa_enabled"`
}

type resetPasswordReq struct {
	Password string `json:"password" binding:"required,min=8"`
}

func (h *AdminHandler) ListUsers(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	users, err := h.userRepo.List(c.Request.Context(), tenantID, c.Query("search"), c.Query("status"))
	if err != nil {
		log.Err(err).Msg("list users failed")
		response.InternalError(c, "failed to list users")
		return
	}
	response.OK(c, users)
}

func (h *AdminHandler) GetUser(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	userID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid user id")
		return
	}
	user, err := h.userRepo.Get(c.Request.Context(), tenantID, userID)
	if err != nil {
		log.Err(err).Msg("get user failed")
		response.InternalError(c, "failed to get user")
		return
	}
	if user == nil {
		response.NotFound(c, "user not found")
		return
	}
	response.OK(c, user)
}

func (h *AdminHandler) CreateUser(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	adminID, _ := uuid.Parse(c.GetString("user_id"))

	var req createUserReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		response.InternalError(c, "failed to hash password")
		return
	}

	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}
	user := repository.NewAdminUser(tenantID, req.Email, req.DisplayName, req.Phone, active)
	user.AvatarURL = req.AvatarURL
	user.IsMFAEnabled = req.IsMFAEnabled

	if err := h.userRepo.Create(c.Request.Context(), user, string(hash)); err != nil {
		log.Err(err).Msg("create user failed")
		response.InternalError(c, err.Error())
		return
	}
	for _, rawRoleID := range req.RoleIDs {
		roleID, err := uuid.Parse(rawRoleID)
		if err == nil {
			_ = h.roleRepo.AssignRole(c.Request.Context(), user.ID, roleID, &adminID)
		}
	}

	created, _ := h.userRepo.Get(c.Request.Context(), tenantID, user.ID)
	response.Created(c, created)
}

func (h *AdminHandler) UpdateUser(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	userID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid user id")
		return
	}
	var req updateUserReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	user := &models.AdminUser{
		ID:           userID,
		Email:        req.Email,
		DisplayName:  req.DisplayName,
		Phone:        req.Phone,
		AvatarURL:    req.AvatarURL,
		IsActive:     req.IsActive,
		IsMFAEnabled: req.IsMFAEnabled,
	}
	if err := h.userRepo.Update(c.Request.Context(), tenantID, user); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			response.NotFound(c, "user not found")
			return
		}
		log.Err(err).Msg("update user failed")
		response.InternalError(c, err.Error())
		return
	}
	updated, _ := h.userRepo.Get(c.Request.Context(), tenantID, userID)
	response.OK(c, updated)
}

func (h *AdminHandler) SetUserActive(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	userID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid user id")
		return
	}
	var req struct {
		IsActive bool `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.userRepo.SetActive(c.Request.Context(), tenantID, userID, req.IsActive); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			response.NotFound(c, "user not found")
			return
		}
		log.Err(err).Msg("set user active failed")
		response.InternalError(c, "failed to update status")
		return
	}
	response.OK(c, gin.H{"message": "user status updated"})
}

func (h *AdminHandler) ResetUserPassword(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	userID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid user id")
		return
	}
	var req resetPasswordReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		response.InternalError(c, "failed to hash password")
		return
	}
	if err := h.userRepo.ResetPassword(c.Request.Context(), tenantID, userID, string(hash)); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			response.NotFound(c, "user not found")
			return
		}
		log.Err(err).Msg("reset password failed")
		response.InternalError(c, "failed to reset password")
		return
	}
	response.OK(c, gin.H{"message": "password reset"})
}

// ==================== Auth Objects ====================

type createAuthObjectReq struct {
	ObjectClass string   `json:"object_class" binding:"required"`
	ObjectCode  string   `json:"object_code" binding:"required"`
	Description string   `json:"description"`
	Activities  []string `json:"activities"`
}

func (h *AdminHandler) CreateAuthObject(c *gin.Context) {
	var req createAuthObjectReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	now := time.Now()
	obj := &models.AuthObject{
		ID:          uuid.New(),
		ObjectClass: req.ObjectClass,
		ObjectCode:  req.ObjectCode,
		Description: req.Description,
		Activities:  req.Activities,
		IsActive:    true,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if err := h.authObjRepo.Create(c.Request.Context(), obj); err != nil {
		log.Err(err).Msg("create auth object failed")
		response.InternalError(c, err.Error())
		return
	}

	response.Created(c, obj)
}

func (h *AdminHandler) ListAuthObjects(c *gin.Context) {
	class := c.Query("class")
	objs, err := h.authObjRepo.List(c.Request.Context(), class)
	if err != nil {
		log.Err(err).Msg("list auth objects failed")
		response.InternalError(c, "failed to list auth objects")
		return
	}
	response.OK(c, objs)
}

func (h *AdminHandler) GetAuthObject(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	obj, err := h.authObjRepo.GetByID(c.Request.Context(), id)
	if err != nil || obj == nil {
		response.NotFound(c, "auth object not found")
		return
	}

	fields, _ := h.authObjRepo.ListFields(c.Request.Context(), id)
	response.OK(c, gin.H{"object": obj, "fields": fields})
}

func (h *AdminHandler) UpdateAuthObject(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}

	var req createAuthObjectReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	obj := &models.AuthObject{
		ID:          id,
		ObjectClass: req.ObjectClass,
		ObjectCode:  req.ObjectCode,
		Description: req.Description,
		Activities:  req.Activities,
	}

	if err := h.authObjRepo.Update(c.Request.Context(), obj); err != nil {
		log.Err(err).Msg("update auth object failed")
		response.InternalError(c, "failed to update")
		return
	}

	response.OK(c, gin.H{"message": "updated"})
}

func (h *AdminHandler) DeleteAuthObject(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.authObjRepo.Delete(c.Request.Context(), id); err != nil {
		log.Err(err).Msg("delete auth object failed")
		response.InternalError(c, "failed to delete")
		return
	}
	response.OK(c, gin.H{"message": "deleted"})
}

// ==================== Object Fields ====================

type createFieldReq struct {
	FieldName    string `json:"field_name" binding:"required"`
	FieldLabel   string `json:"field_label"`
	FieldType    string `json:"field_type"`
	IsRequired   bool   `json:"is_required"`
	DisplayOrder int    `json:"display_order"`
}

func (h *AdminHandler) AddObjectField(c *gin.Context) {
	objID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid auth object id")
		return
	}

	var req createFieldReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	field := &models.AuthObjectField{
		ID:           uuid.New(),
		AuthObjectID: objID,
		FieldName:    req.FieldName,
		FieldLabel:   req.FieldLabel,
		FieldType:    req.FieldType,
		IsRequired:   req.IsRequired,
		DisplayOrder: req.DisplayOrder,
	}

	if err := h.authObjRepo.CreateField(c.Request.Context(), field); err != nil {
		log.Err(err).Msg("create field failed")
		response.InternalError(c, "failed to create field")
		return
	}

	response.Created(c, field)
}

func (h *AdminHandler) DeleteObjectField(c *gin.Context) {
	fieldID, err := uuid.Parse(c.Param("fieldId"))
	if err != nil {
		response.BadRequest(c, "invalid field id")
		return
	}
	if err := h.authObjRepo.DeleteField(c.Request.Context(), fieldID); err != nil {
		log.Err(err).Msg("delete field failed")
		response.InternalError(c, "failed to delete field")
		return
	}
	response.OK(c, gin.H{"message": "deleted"})
}

// ==================== Roles ====================

type createRoleReq struct {
	RoleID       string `json:"role_id" binding:"required"`
	Description  string `json:"description"`
	RoleType     string `json:"role_type"`
	RoleCategory string `json:"role_category"`
	IsSystem     bool   `json:"is_system"`
}

func (h *AdminHandler) CreateRole(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))

	var req createRoleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	now := time.Now()
	role := &models.RoleMaster{
		ID:           uuid.New(),
		TenantID:     tenantID,
		RoleID:       req.RoleID,
		Description:  req.Description,
		RoleType:     req.RoleType,
		RoleCategory: req.RoleCategory,
		IsActive:     true,
		IsSystem:     req.IsSystem,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	if err := h.roleRepo.Create(c.Request.Context(), role); err != nil {
		log.Err(err).Msg("create role failed")
		response.InternalError(c, "failed to create role")
		return
	}

	response.Created(c, role)
}

func (h *AdminHandler) ListRoles(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	category := c.Query("category")

	roles, err := h.roleRepo.List(c.Request.Context(), tenantID, category)
	if err != nil {
		log.Err(err).Msg("list roles failed")
		response.InternalError(c, "failed to list roles")
		return
	}
	response.OK(c, roles)
}

func (h *AdminHandler) GetRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	role, err := h.roleRepo.GetByID(c.Request.Context(), id)
	if err != nil || role == nil {
		response.NotFound(c, "role not found")
		return
	}

	authVals, _ := h.authValRepo.GetAuthValues(c.Request.Context(), id)
	response.OK(c, gin.H{"role": role, "auth_values": authVals})
}

func (h *AdminHandler) DeleteRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	if err := h.roleRepo.Delete(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete role failed")
		response.InternalError(c, "failed to delete role")
		return
	}
	response.OK(c, gin.H{"message": "deleted"})
}

// ==================== Auth Values ====================

type setAuthValueReq struct {
	AuthObjectID     string                       `json:"auth_object_id" binding:"required"`
	ActivityCreate   bool                         `json:"activity_create"`
	ActivityRead     bool                         `json:"activity_read"`
	ActivityUpdate   bool                         `json:"activity_update"`
	ActivityDelete   bool                         `json:"activity_delete"`
	ActivityApprove  bool                         `json:"activity_approve"`
	ActivityPrint    bool                         `json:"activity_print"`
	ActivityTransfer bool                         `json:"activity_transfer"`
	ActivityClose    bool                         `json:"activity_close"`
	FieldValues      map[string]string            `json:"field_values"`
	FieldRanges      map[string]models.FieldRange `json:"field_ranges"`
}

func (h *AdminHandler) SetAuthValue(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("roleId"))
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}

	var req setAuthValueReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	authObjID, _ := uuid.Parse(req.AuthObjectID)
	if req.FieldValues == nil {
		req.FieldValues = make(map[string]string)
	}
	if req.FieldRanges == nil {
		req.FieldRanges = make(map[string]models.FieldRange)
	}

	av := &models.RoleAuthValue{
		ID:               uuid.New(),
		RoleID:           roleID,
		AuthObjectID:     authObjID,
		ActivityCreate:   req.ActivityCreate,
		ActivityRead:     req.ActivityRead,
		ActivityUpdate:   req.ActivityUpdate,
		ActivityDelete:   req.ActivityDelete,
		ActivityApprove:  req.ActivityApprove,
		ActivityPrint:    req.ActivityPrint,
		ActivityTransfer: req.ActivityTransfer,
		ActivityClose:    req.ActivityClose,
		FieldValues:      req.FieldValues,
		FieldRanges:      req.FieldRanges,
	}

	if err := h.authValRepo.SetAuthValue(c.Request.Context(), av); err != nil {
		log.Err(err).Msg("set auth value failed")
		response.InternalError(c, "failed to set authorization values")
		return
	}

	response.OK(c, av)
}

func (h *AdminHandler) GetAuthValues(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("roleId"))
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}

	vals, err := h.authValRepo.GetAuthValues(c.Request.Context(), roleID)
	if err != nil {
		log.Err(err).Msg("get auth values failed")
		response.InternalError(c, "failed to get auth values")
		return
	}

	response.OK(c, vals)
}

// ==================== User-Role Assignment ====================

type assignRoleReq struct {
	UserID string `json:"user_id" binding:"required"`
	RoleID string `json:"role_id" binding:"required"`
}

func (h *AdminHandler) AssignUserRole(c *gin.Context) {
	var req assignRoleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	userID, _ := uuid.Parse(req.UserID)
	roleID, _ := uuid.Parse(req.RoleID)
	adminID, _ := uuid.Parse(c.GetString("user_id"))

	if err := h.roleRepo.AssignRole(c.Request.Context(), userID, roleID, &adminID); err != nil {
		log.Err(err).Msg("assign role failed")
		response.InternalError(c, "failed to assign role")
		return
	}

	response.OK(c, gin.H{"message": "role assigned"})
}

func (h *AdminHandler) RemoveUserRole(c *gin.Context) {
	userID, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		response.BadRequest(c, "invalid user id")
		return
	}
	roleID, err := uuid.Parse(c.Param("roleId"))
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}

	if err := h.roleRepo.RemoveRole(c.Request.Context(), userID, roleID); err != nil {
		log.Err(err).Msg("remove role failed")
		response.InternalError(c, "failed to remove role")
		return
	}

	response.OK(c, gin.H{"message": "role removed"})
}

// ==================== User Permissions ====================

func (h *AdminHandler) GetUserPermissions(c *gin.Context) {
	userID := c.Param("userId")
	roles, err := h.roleRepo.GetEffectiveRoles(c.Request.Context(), uuid.MustParse(userID))
	if err != nil {
		log.Err(err).Msg("get user permissions failed")
		response.InternalError(c, "failed to get permissions")
		return
	}

	response.OK(c, roles)
}

// ==================== Permission Check ====================

func (h *AdminHandler) CheckPermission(c *gin.Context) {
	userID := c.GetString("user_id")
	objectCode := c.Query("object")
	activity := c.Query("activity")

	if objectCode == "" || activity == "" {
		response.BadRequest(c, "object and activity query params required")
		return
	}

	// Return user's auth values for the given object
	// This is a proxy check — the actual engine does full evaluation
	response.OK(c, gin.H{
		"user_id":  userID,
		"object":   objectCode,
		"activity": activity,
	})
}

// CheckPermissionPOST handles POST /permissions/check for the engine
func (h *AdminHandler) CheckPermissionPOST(c *gin.Context) {
	var req models.PermissionCheckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	// For now return a simple check result
	response.OK(c, &models.PermissionCheckResult{
		Granted:   true,
		MatchedBy: "admin",
	})
}
