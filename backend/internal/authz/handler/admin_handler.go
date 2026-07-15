package handler

import (
	"encoding/json"
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
	sodRepo     *repository.SoDRepo
	orgRepo     *repository.OrgRepo
	accessRepo  *repository.AccessRequestRepo
	auditRepo   *repository.AuditRepo
}

func NewAdminHandler(
	authObjRepo *repository.AuthObjectRepo,
	roleRepo *repository.RoleRepo,
	authValRepo *repository.AuthValueRepo,
	userRepo *repository.UserRepo,
	sodRepo *repository.SoDRepo,
	orgRepo *repository.OrgRepo,
	accessRepo *repository.AccessRequestRepo,
	auditRepo *repository.AuditRepo,
) *AdminHandler {
	return &AdminHandler{
		authObjRepo: authObjRepo,
		roleRepo:    roleRepo,
		authValRepo: authValRepo,
		userRepo:    userRepo,
		sodRepo:     sodRepo,
		orgRepo:     orgRepo,
		accessRepo:  accessRepo,
		auditRepo:   auditRepo,
	}
}

func (h *AdminHandler) audit(c *gin.Context, action, entityType string, entityID *uuid.UUID, oldValues, newValues interface{}) {
	if h.auditRepo == nil {
		return
	}
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	var userID *uuid.UUID
	if raw := c.GetString("user_id"); raw != "" {
		if id, err := uuid.Parse(raw); err == nil {
			userID = &id
		}
	}
	h.auditRepo.Record(c.Request.Context(), tenantID, userID, action, entityType, entityID, oldValues, newValues, c.ClientIP(), c.Request.UserAgent())
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
	for _, obj := range objs {
		fields, err := h.authObjRepo.ListFields(c.Request.Context(), obj.ID)
		if err != nil {
			log.Err(err).Str("auth_object_id", obj.ID.String()).Msg("list auth object fields failed")
			response.InternalError(c, "failed to list auth object fields")
			return
		}
		for _, field := range fields {
			obj.Fields = append(obj.Fields, *field)
		}
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
	ParentRoleID string `json:"parent_role_id"`
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
	var parentRoleID *uuid.UUID
	if req.ParentRoleID != "" {
		id, err := uuid.Parse(req.ParentRoleID)
		if err != nil {
			response.BadRequest(c, "invalid parent role id")
			return
		}
		parentRoleID = &id
	}
	role := &models.RoleMaster{
		ID:           uuid.New(),
		TenantID:     tenantID,
		RoleID:       req.RoleID,
		Description:  req.Description,
		RoleType:     req.RoleType,
		RoleCategory: req.RoleCategory,
		ParentRoleID: parentRoleID,
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

func (h *AdminHandler) UpdateRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))

	var req createRoleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	role, err := h.roleRepo.GetByID(c.Request.Context(), id)
	if err != nil || role == nil || role.TenantID != tenantID {
		response.NotFound(c, "role not found")
		return
	}
	if role.IsSystem {
		response.BadRequest(c, "system roles cannot be updated")
		return
	}

	var parentRoleID *uuid.UUID
	if req.ParentRoleID != "" {
		parentID, err := uuid.Parse(req.ParentRoleID)
		if err != nil {
			response.BadRequest(c, "invalid parent role id")
			return
		}
		if parentID == id {
			response.BadRequest(c, "derived role cannot inherit from itself")
			return
		}
		parentRoleID = &parentID
	}

	role.RoleID = req.RoleID
	role.Description = req.Description
	role.RoleType = req.RoleType
	role.RoleCategory = req.RoleCategory
	role.ParentRoleID = parentRoleID
	role.InheritLevel = 0
	if parentRoleID != nil {
		role.InheritLevel = 1
	}

	if err := h.roleRepo.Update(c.Request.Context(), role); err != nil {
		log.Err(err).Msg("update role failed")
		response.InternalError(c, "failed to update role")
		return
	}
	response.OK(c, role)
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
	members, _ := h.roleRepo.ListCompositeMembers(c.Request.Context(), id)
	response.OK(c, gin.H{"role": role, "auth_values": authVals, "members": members})
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

func (h *AdminHandler) ListCompositeMembers(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}
	members, err := h.roleRepo.ListCompositeMembers(c.Request.Context(), roleID)
	if err != nil {
		log.Err(err).Msg("list composite role members failed")
		response.InternalError(c, "failed to list role members")
		return
	}
	response.OK(c, members)
}

type compositeMemberReq struct {
	ChildRoleID string `json:"child_role_id" binding:"required"`
}

func (h *AdminHandler) AddCompositeMember(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}
	var req compositeMemberReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	childID, err := uuid.Parse(req.ChildRoleID)
	if err != nil {
		response.BadRequest(c, "invalid child role id")
		return
	}
	if err := h.roleRepo.AddCompositeMember(c.Request.Context(), roleID, childID); err != nil {
		log.Err(err).Msg("add composite member failed")
		response.BadRequest(c, err.Error())
		return
	}
	response.OK(c, gin.H{"message": "member added"})
}

func (h *AdminHandler) RemoveCompositeMember(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}
	childID, err := uuid.Parse(c.Param("childId"))
	if err != nil {
		response.BadRequest(c, "invalid child role id")
		return
	}
	if err := h.roleRepo.RemoveCompositeMember(c.Request.Context(), roleID, childID); err != nil {
		log.Err(err).Msg("remove composite member failed")
		response.InternalError(c, "failed to remove member")
		return
	}
	response.OK(c, gin.H{"message": "member removed"})
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

	h.audit(c, "role_auth_value.set", "role_auth_value", &av.ID, nil, av)
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
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))

	conflicts, err := h.sodRepo.CheckRoleAssignmentConflicts(c.Request.Context(), tenantID, userID, roleID)
	if err != nil {
		log.Err(err).Msg("sod conflict check failed")
		response.InternalError(c, "failed to check SoD conflicts")
		return
	}
	if len(conflicts) > 0 {
		h.audit(c, "sod.block_role_assignment", "user_role_assignment", &roleID, nil, gin.H{
			"user_id":   userID,
			"role_id":   roleID,
			"conflicts": conflicts,
		})
		c.JSON(400, gin.H{"success": false, "message": "SoD conflict detected", "conflicts": conflicts})
		return
	}

	if err := h.roleRepo.AssignRole(c.Request.Context(), userID, roleID, &adminID); err != nil {
		log.Err(err).Msg("assign role failed")
		response.InternalError(c, "failed to assign role")
		return
	}

	h.audit(c, "user_role.assign", "user_role_assignment", &roleID, nil, gin.H{"user_id": userID, "role_id": roleID})
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

	h.audit(c, "user_role.remove", "user_role_assignment", &roleID, nil, gin.H{"user_id": userID, "role_id": roleID})
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

	items := make([]gin.H, 0, len(roles))
	for _, role := range roles {
		authValues, err := h.authValRepo.GetAuthValues(c.Request.Context(), role.ID)
		if err != nil {
			log.Err(err).Str("role_id", role.ID.String()).Msg("get role auth values failed")
			response.InternalError(c, "failed to get permissions")
			return
		}
		items = append(items, gin.H{
			"role":        role,
			"auth_values": authValues,
		})
	}

	response.OK(c, items)
}

// ==================== SoD Rules ====================

type createSoDRuleReq struct {
	RuleCode     string `json:"rule_code" binding:"required"`
	Description  string `json:"description"`
	Severity     string `json:"severity"`
	RiskCategory string `json:"risk_category"`
	ObjectAID    string `json:"object_a_id" binding:"required"`
	ActivityA    string `json:"activity_a"`
	ObjectBID    string `json:"object_b_id" binding:"required"`
	ActivityB    string `json:"activity_b"`
	IsActive     *bool  `json:"is_active"`
}

func (h *AdminHandler) ListSoDRules(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	rules, err := h.sodRepo.ListRules(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list sod rules failed")
		response.InternalError(c, "failed to list SoD rules")
		return
	}
	response.OK(c, rules)
}

func (h *AdminHandler) CreateSoDRule(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	var req createSoDRuleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	objectAID, err := uuid.Parse(req.ObjectAID)
	if err != nil {
		response.BadRequest(c, "invalid object A id")
		return
	}
	objectBID, err := uuid.Parse(req.ObjectBID)
	if err != nil {
		response.BadRequest(c, "invalid object B id")
		return
	}
	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}
	severity := req.Severity
	if severity == "" {
		severity = "medium"
	}
	rule := &models.SoDRule{
		ID:           uuid.New(),
		TenantID:     tenantID,
		RuleCode:     req.RuleCode,
		Description:  req.Description,
		Severity:     severity,
		RiskCategory: req.RiskCategory,
		ObjectAID:    objectAID,
		ActivityA:    req.ActivityA,
		ObjectBID:    objectBID,
		ActivityB:    req.ActivityB,
		IsActive:     active,
	}
	if err := h.sodRepo.CreateRule(c.Request.Context(), rule); err != nil {
		log.Err(err).Msg("create sod rule failed")
		response.InternalError(c, "failed to create SoD rule")
		return
	}
	h.audit(c, "sod_rule.create", "sod_rule", &rule.ID, nil, rule)
	response.Created(c, rule)
}

func (h *AdminHandler) DeleteSoDRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid SoD rule id")
		return
	}
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	if err := h.sodRepo.DeleteRule(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete sod rule failed")
		response.InternalError(c, "failed to delete SoD rule")
		return
	}
	h.audit(c, "sod_rule.delete", "sod_rule", &id, nil, gin.H{"id": id})
	response.OK(c, gin.H{"message": "deleted"})
}

// ==================== Org Units ====================

type createOrgUnitReq struct {
	ParentID  string `json:"parent_id"`
	OrgCode   string `json:"org_code" binding:"required"`
	OrgName   string `json:"org_name" binding:"required"`
	OrgType   string `json:"org_type" binding:"required"`
	IsActive  *bool  `json:"is_active"`
	ManagerID string `json:"manager_id"`
}

func (h *AdminHandler) ListOrgUnits(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	units, err := h.orgRepo.List(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list org units failed")
		response.InternalError(c, "failed to list org units")
		return
	}
	response.OK(c, units)
}

func (h *AdminHandler) CreateOrgUnit(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	var req createOrgUnitReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}
	var parentID *uuid.UUID
	if req.ParentID != "" {
		id, err := uuid.Parse(req.ParentID)
		if err != nil {
			response.BadRequest(c, "invalid parent org unit id")
			return
		}
		parentID = &id
	}
	var managerID *uuid.UUID
	if req.ManagerID != "" {
		id, err := uuid.Parse(req.ManagerID)
		if err != nil {
			response.BadRequest(c, "invalid manager id")
			return
		}
		managerID = &id
	}
	unit := &models.OrgUnit{
		ID:        uuid.New(),
		TenantID:  tenantID,
		ParentID:  parentID,
		OrgCode:   req.OrgCode,
		OrgName:   req.OrgName,
		OrgType:   req.OrgType,
		IsActive:  active,
		ManagerID: managerID,
	}
	if err := h.orgRepo.Create(c.Request.Context(), unit); err != nil {
		log.Err(err).Msg("create org unit failed")
		response.InternalError(c, "failed to create org unit")
		return
	}
	response.Created(c, unit)
}

func (h *AdminHandler) DeleteOrgUnit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid org unit id")
		return
	}
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	if err := h.orgRepo.Delete(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete org unit failed")
		response.InternalError(c, "failed to delete org unit")
		return
	}
	response.OK(c, gin.H{"message": "deleted"})
}

// ==================== Access Requests ====================

type createAccessRequestReq struct {
	TargetUserID  string          `json:"target_user_id" binding:"required"`
	RequestType   string          `json:"request_type" binding:"required"`
	RequestData   json.RawMessage `json:"request_data" binding:"required"`
	Justification string          `json:"justification"`
	Urgency       string          `json:"urgency"`
}

type approveAccessRequestReq struct {
	Comment string `json:"comment"`
}

func (h *AdminHandler) ListAccessRequests(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	requests, err := h.accessRepo.List(c.Request.Context(), tenantID, c.Query("status"))
	if err != nil {
		log.Err(err).Msg("list access requests failed")
		response.InternalError(c, "failed to list access requests")
		return
	}
	response.OK(c, requests)
}

func (h *AdminHandler) CreateAccessRequest(c *gin.Context) {
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	requesterID, _ := uuid.Parse(c.GetString("user_id"))
	var req createAccessRequestReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	targetUserID, err := uuid.Parse(req.TargetUserID)
	if err != nil {
		response.BadRequest(c, "invalid target user id")
		return
	}
	urgency := req.Urgency
	if urgency == "" {
		urgency = "normal"
	}
	accessReq := &models.AccessRequest{
		ID:            uuid.New(),
		TenantID:      tenantID,
		RequesterID:   requesterID,
		TargetUserID:  targetUserID,
		RequestType:   req.RequestType,
		RequestData:   req.RequestData,
		Justification: req.Justification,
		Urgency:       urgency,
	}
	if err := h.accessRepo.Create(c.Request.Context(), accessReq); err != nil {
		log.Err(err).Msg("create access request failed")
		response.InternalError(c, "failed to create access request")
		return
	}
	h.audit(c, "access_request.create", "access_request", &accessReq.ID, nil, accessReq)
	response.Created(c, accessReq)
}

func (h *AdminHandler) ApproveAccessRequest(c *gin.Context) {
	h.setAccessRequestApproval(c, "approved")
}

func (h *AdminHandler) RejectAccessRequest(c *gin.Context) {
	h.setAccessRequestApproval(c, "rejected")
}

func (h *AdminHandler) setAccessRequestApproval(c *gin.Context, status string) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid access request id")
		return
	}
	var req approveAccessRequestReq
	_ = c.ShouldBindJSON(&req)
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	approverID, _ := uuid.Parse(c.GetString("user_id"))
	if err := h.accessRepo.Approve(c.Request.Context(), id, tenantID, approverID, status, req.Comment); err != nil {
		log.Err(err).Msg("approve access request failed")
		response.InternalError(c, "failed to update access request")
		return
	}
	h.audit(c, "access_request."+status, "access_request", &id, nil, gin.H{"status": status, "comment": req.Comment})
	response.OK(c, gin.H{"message": status})
}

func (h *AdminHandler) ExecuteAccessRequest(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid access request id")
		return
	}
	tenantID, _ := uuid.Parse(c.GetString("tenant_id"))
	req, err := h.accessRepo.Get(c.Request.Context(), id, tenantID)
	if err != nil {
		response.NotFound(c, "access request not found")
		return
	}
	if req.ApprovalStatus != "approved" {
		response.BadRequest(c, "access request is not approved")
		return
	}
	if req.Executed {
		response.BadRequest(c, "access request already executed")
		return
	}

	var data struct {
		RoleID string `json:"role_id"`
	}
	if err := json.Unmarshal(req.RequestData, &data); err != nil || data.RoleID == "" {
		response.BadRequest(c, "request data must include role_id")
		return
	}
	roleID, err := uuid.Parse(data.RoleID)
	if err != nil {
		response.BadRequest(c, "invalid role id")
		return
	}

	switch req.RequestType {
	case "role_assign":
		conflicts, err := h.sodRepo.CheckRoleAssignmentConflicts(c.Request.Context(), tenantID, req.TargetUserID, roleID)
		if err != nil {
			log.Err(err).Msg("sod conflict check failed")
			response.InternalError(c, "failed to check SoD conflicts")
			return
		}
		if len(conflicts) > 0 {
			h.audit(c, "sod.block_access_request_execute", "access_request", &id, nil, gin.H{"role_id": roleID, "conflicts": conflicts})
			c.JSON(400, gin.H{"success": false, "message": "SoD conflict detected", "conflicts": conflicts})
			return
		}
		approverID, _ := uuid.Parse(c.GetString("user_id"))
		if err := h.roleRepo.AssignRole(c.Request.Context(), req.TargetUserID, roleID, &approverID); err != nil {
			log.Err(err).Msg("execute role assignment request failed")
			response.InternalError(c, "failed to assign role")
			return
		}
	case "role_remove":
		if err := h.roleRepo.RemoveRole(c.Request.Context(), req.TargetUserID, roleID); err != nil {
			log.Err(err).Msg("execute role removal request failed")
			response.InternalError(c, "failed to remove role")
			return
		}
	default:
		response.BadRequest(c, "unsupported request type")
		return
	}

	if err := h.accessRepo.MarkExecuted(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("mark access request executed failed")
		response.InternalError(c, "failed to mark executed")
		return
	}
	h.audit(c, "access_request.execute", "access_request", &id, nil, req)
	response.OK(c, gin.H{"message": "executed"})
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
