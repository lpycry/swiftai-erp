package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type AuthObjectRepo struct {
	db *pgxpool.Pool
}

func NewAuthObjectRepo(db *pgxpool.Pool) *AuthObjectRepo {
	return &AuthObjectRepo{db: db}
}

func (r *AuthObjectRepo) Create(ctx context.Context, obj *models.AuthObject) error {
	query := `
		INSERT INTO auth_objects (id, object_class, object_code, description, activities, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err := r.db.Exec(ctx, query,
		obj.ID, obj.ObjectClass, obj.ObjectCode, obj.Description,
		obj.Activities, obj.IsActive, obj.CreatedAt, obj.UpdatedAt)
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") {
			return fmt.Errorf("auth object code '%s' already exists", obj.ObjectCode)
		}
		return fmt.Errorf("create auth object: %w", err)
	}
	return nil
}

func (r *AuthObjectRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.AuthObject, error) {
	query := `
		SELECT id, object_class, object_code, COALESCE(description,''), activities, is_active, created_at, updated_at
		FROM auth_objects WHERE id = $1
	`
	obj := &models.AuthObject{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&obj.ID, &obj.ObjectClass, &obj.ObjectCode, &obj.Description,
		&obj.Activities, &obj.IsActive, &obj.CreatedAt, &obj.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get auth object: %w", err)
	}
	return obj, nil
}

func (r *AuthObjectRepo) GetByCode(ctx context.Context, code string) (*models.AuthObject, error) {
	query := `
		SELECT id, object_class, object_code, COALESCE(description,''), activities, is_active, created_at, updated_at
		FROM auth_objects WHERE object_code = $1
	`
	obj := &models.AuthObject{}
	err := r.db.QueryRow(ctx, query, code).Scan(
		&obj.ID, &obj.ObjectClass, &obj.ObjectCode, &obj.Description,
		&obj.Activities, &obj.IsActive, &obj.CreatedAt, &obj.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get auth object by code: %w", err)
	}
	return obj, nil
}

func (r *AuthObjectRepo) List(ctx context.Context, class string) ([]*models.AuthObject, error) {
	var rows pgx.Rows
	var err error
	if class != "" {
		rows, err = r.db.Query(ctx,
			`SELECT id, object_class, object_code, COALESCE(description,''), activities, is_active, created_at, updated_at
			 FROM auth_objects WHERE object_class = $1 ORDER BY object_code`, class)
	} else {
		rows, err = r.db.Query(ctx,
			`SELECT id, object_class, object_code, COALESCE(description,''), activities, is_active, created_at, updated_at
			 FROM auth_objects ORDER BY object_class, object_code`)
	}
	if err != nil {
		return nil, fmt.Errorf("list auth objects: %w", err)
	}
	defer rows.Close()

	var objs []*models.AuthObject
	for rows.Next() {
		obj := &models.AuthObject{}
		if err := rows.Scan(&obj.ID, &obj.ObjectClass, &obj.ObjectCode, &obj.Description,
			&obj.Activities, &obj.IsActive, &obj.CreatedAt, &obj.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan auth object: %w", err)
		}
		objs = append(objs, obj)
	}
	return objs, nil
}

func (r *AuthObjectRepo) Update(ctx context.Context, obj *models.AuthObject) error {
	query := `
		UPDATE auth_objects SET object_class=$1, object_code=$2, description=$3,
		       activities=$4, is_active=$5, updated_at=NOW()
		WHERE id=$6
	`
	_, err := r.db.Exec(ctx, query,
		obj.ObjectClass, obj.ObjectCode, obj.Description,
		obj.Activities, obj.IsActive, obj.ID)
	return err
}

func (r *AuthObjectRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM auth_objects WHERE id=$1`, id)
	return err
}

// ---- Auth Object Fields ----

func (r *AuthObjectRepo) CreateField(ctx context.Context, field *models.AuthObjectField) error {
	query := `
		INSERT INTO auth_object_fields (id, auth_object_id, field_name, field_label, field_type, is_required, display_order)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.Exec(ctx, query,
		field.ID, field.AuthObjectID, field.FieldName, field.FieldLabel,
		field.FieldType, field.IsRequired, field.DisplayOrder)
	return err
}

func (r *AuthObjectRepo) ListFields(ctx context.Context, authObjectID uuid.UUID) ([]*models.AuthObjectField, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, auth_object_id, field_name, COALESCE(field_label,''), field_type, is_required, display_order
		 FROM auth_object_fields WHERE auth_object_id = $1 ORDER BY display_order`,
		authObjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var fields []*models.AuthObjectField
	for rows.Next() {
		f := &models.AuthObjectField{}
		if err := rows.Scan(&f.ID, &f.AuthObjectID, &f.FieldName, &f.FieldLabel,
			&f.FieldType, &f.IsRequired, &f.DisplayOrder); err != nil {
			return nil, err
		}
		fields = append(fields, f)
	}
	return fields, nil
}

func (r *AuthObjectRepo) DeleteField(ctx context.Context, fieldID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM auth_object_fields WHERE id=$1`, fieldID)
	return err
}
