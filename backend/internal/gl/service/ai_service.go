package service

import (
	"context"
	"fmt"
	"math"
	"strings"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	"github.com/swiftai-erp/backend/internal/gl/repository"
)

// AIService provides NLP-based account suggestion for journal entries.
// In production, this would call an external LLM or ML service.
// For Phase 2, we implement a rule-based keyword matching engine.
type AIService struct {
	accountRepo *repository.AccountRepo
}

func NewAIService(accountRepo *repository.AccountRepo) *AIService {
	return &AIService{accountRepo: accountRepo}
}

// SuggestAccounts takes a natural-language description and optional amount,
// and returns suggested account assignments with confidence scores.
func (s *AIService) SuggestAccounts(ctx context.Context, tenantID uuid.UUID, req *glmodels.AISuggestRequest) (*glmodels.AISuggestResponse, error) {
	leafAccounts, err := s.accountRepo.ListLeafAccounts(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("load leaf accounts: %w", err)
	}

	input := strings.ToLower(req.NaturalLanguage)
	input = strings.TrimSpace(input)

	// Rule-based keyword matching
	matches := s.matchKeywords(input, leafAccounts)

	if len(matches) == 0 {
		return &glmodels.AISuggestResponse{
			Description:    req.NaturalLanguage,
			SuggestedLines: nil,
			Confidence:     0.0,
		}, nil
	}

	// Build suggested lines: group by debit/credit pattern
	// For simplicity, assume first match is debit, rest are credits
	// or split based on amount
	suggestedLines := s.buildSuggestedLines(matches, req.Amount)

	overallConfidence := 0.0
	if len(suggestedLines) > 0 {
		sum := 0.0
		for _, l := range suggestedLines {
			sum += l.Confidence
		}
		overallConfidence = math.Round(sum/float64(len(suggestedLines))*100) / 100
	}

	return &glmodels.AISuggestResponse{
		Description:    req.NaturalLanguage,
		SuggestedLines: suggestedLines,
		Confidence:     overallConfidence,
	}, nil
}

type scoredAccount struct {
	account    *glmodels.Account
	score      float64
	matchField string
}

// matchKeywords scores all leaf accounts against the input text.
func (s *AIService) matchKeywords(input string, accounts []*glmodels.Account) []scoredAccount {
	keywords := tokenize(input)
	if len(keywords) == 0 {
		return nil
	}

	var scored []scoredAccount
	for _, acc := range accounts {
		score := s.scoreAccount(acc, keywords)
		if score > 0 {
			scored = append(scored, scoredAccount{
				account: acc,
				score:   score,
			})
		}
	}

	// Sort by score descending
	for i := 0; i < len(scored); i++ {
		for j := i + 1; j < len(scored); j++ {
			if scored[j].score > scored[i].score {
				scored[i], scored[j] = scored[j], scored[i]
			}
		}
	}

	// Take top matches
	if len(scored) > 5 {
		scored = scored[:5]
	}

	return scored
}

// scoreAccount computes a match score for a single account against input keywords.
func (s *AIService) scoreAccount(acc *glmodels.Account, keywords []string) float64 {
	score := 0.0
	name := strings.ToLower(acc.AccountName)
	code := acc.AccountCode
	desc := strings.ToLower(acc.Description)
	at := strings.ToLower(acc.AccountType)

	for _, kw := range keywords {
		// Exact name match (highest weight)
		if name == kw {
			score += 10.0
			continue
		}
		// Name contains keyword
		if strings.Contains(name, kw) {
			score += 5.0
			continue
		}
		// Description contains keyword
		if strings.Contains(desc, kw) {
			score += 3.0
			continue
		}
		// Code match
		if code == strings.ToUpper(kw) || code == kw {
			score += 8.0
			continue
		}
		// Partial code match
		if strings.HasPrefix(kw, code) || strings.HasPrefix(code, kw) {
			score += 4.0
		}
	}

	// Boost by type-relevant keywords
	for _, kw := range keywords {
		switch at {
		case "asset":
			if isAssetKeyword(kw) {
				score += 2.0
			}
		case "liability":
			if isLiabilityKeyword(kw) {
				score += 2.0
			}
		case "equity":
			if isEquityKeyword(kw) {
				score += 2.0
			}
		case "revenue":
			if isRevenueKeyword(kw) {
				score += 2.0
			}
		case "expense":
			if isExpenseKeyword(kw) {
				score += 2.0
			}
		}
	}

	return score
}

// buildSuggestedLines creates suggested journal entry lines from scored accounts.
func (s *AIService) buildSuggestedLines(matches []scoredAccount, amount float64) []glmodels.AISuggestedLine {
	if len(matches) == 0 {
		return nil
	}

	if amount <= 0 {
		amount = 100.0 // default amount when not specified
	}

	var lines []glmodels.AISuggestedLine

	// Assign the top match as the main line (debit for expense/asset, credit for revenue/liability)
	primary := matches[0]
	primaryType := primary.account.AccountType

	primaryDebit := 0.0
	primaryCredit := 0.0
	secondaryAmount := amount

	switch primaryType {
	case "asset", "expense":
		primaryDebit = amount
	case "liability", "equity", "revenue":
		primaryCredit = amount
	default:
		primaryDebit = amount
	}

	primaryLine := glmodels.AISuggestedLine{
		AccountID:   primary.account.ID,
		AccountCode: primary.account.AccountCode,
		AccountName: primary.account.AccountName,
		Debit:       primaryDebit,
		Credit:      primaryCredit,
		Description: primary.account.AccountName,
		Confidence:  math.Round(primary.score/10*100) / 100,
	}
	if primaryLine.Confidence > 1.0 {
		primaryLine.Confidence = 1.0
	}
	lines = append(lines, primaryLine)

	// Find a counter account for the other side
	if len(matches) > 1 {
		secondary := matches[1]
		secondaryDebit := 0.0
		secondaryCredit := 0.0

		switch secondary.account.AccountType {
		case "asset", "expense":
			if primaryType != "asset" && primaryType != "expense" {
				secondaryDebit = secondaryAmount
			} else {
				secondaryCredit = secondaryAmount
			}
		case "liability", "equity", "revenue":
			if primaryType != "liability" && primaryType != "equity" && primaryType != "revenue" {
				secondaryCredit = secondaryAmount
			} else {
				secondaryDebit = secondaryAmount
			}
		default:
			if primaryDebit > 0 {
				secondaryCredit = secondaryAmount
			} else {
				secondaryDebit = secondaryAmount
			}
		}

		secondaryLine := glmodels.AISuggestedLine{
			AccountID:   secondary.account.ID,
			AccountCode: secondary.account.AccountCode,
			AccountName: secondary.account.AccountName,
			Debit:       secondaryDebit,
			Credit:      secondaryCredit,
			Description: secondary.account.AccountName,
			Confidence:  math.Round(secondary.score/10*100) / 100,
		}
		if secondaryLine.Confidence > 1.0 {
			secondaryLine.Confidence = 1.0
		}
		lines = append(lines, secondaryLine)
	}

	return lines
}

// tokenize splits input into lowercase tokens.
func tokenize(input string) []string {
	// Remove common punctuation
	replacements := []string{",", ".", "!", "?", ";", ":", "(", ")", "[", "]", "{", "}", "\"", "'", "/", "\\", "-", "_"}
	for _, r := range replacements {
		input = strings.ReplaceAll(input, r, " ")
	}

	tokens := strings.Fields(input)
	// Filter out very short tokens (1-2 chars) and common stop words
	stopWords := map[string]bool{
		"the": true, "a": true, "an": true, "is": true, "are": true,
		"was": true, "were": true, "be": true, "been": true, "being": true,
		"have": true, "has": true, "had": true, "do": true, "does": true,
		"did": true, "will": true, "would": true, "could": true, "should": true,
		"may": true, "might": true, "can": true, "shall": true,
		"to": true, "of": true, "in": true, "for": true, "on": true,
		"with": true, "at": true, "by": true, "from": true, "as": true,
		"into": true, "through": true, "during": true, "before": true,
		"after": true, "above": true, "below": true, "between": true,
		"and": true, "or": true, "but": true, "not": true, "so": true,
		"if": true, "then": true, "than": true, "that": true, "this": true,
		"these": true, "those": true, "it": true, "its": true,
	}

	var result []string
	for _, t := range tokens {
		if len(t) > 2 && !stopWords[t] {
			result = append(result, t)
		}
	}
	return result
}

func isAssetKeyword(kw string) bool {
	keywords := []string{"cash", "bank", "account", "receivable", "inventory",
		"prepaid", "fixed", "asset", "equipment", "building", "land",
		"deposit", "investment", "intangible", "goodwill", "supplies"}
	return containsAny(kw, keywords)
}

func isLiabilityKeyword(kw string) bool {
	keywords := []string{"payable", "accrued", "debt", "loan", "mortgage",
		"liability", "obligation", "note", "bond", "tax", "payroll",
		"unearned", "deposit", "deferred"}
	return containsAny(kw, keywords)
}

func isEquityKeyword(kw string) bool {
	keywords := []string{"equity", "capital", "stock", "retained", "earning",
		"contributed", "surplus", "reserve", "drawing", "owner"}
	return containsAny(kw, keywords)
}

func isRevenueKeyword(kw string) bool {
	keywords := []string{"revenue", "income", "sale", "service", "interest",
		"dividend", "gain", "rental", "fee", "commission", "royalty"}
	return containsAny(kw, keywords)
}

func isExpenseKeyword(kw string) bool {
	keywords := []string{"expense", "cost", "rent", "utility", "salary",
		"wage", "depreciation", "amortization", "advertising", "travel",
		"supply", "maintenance", "insurance", "tax", "interest", "fee",
		"commission", "bad", "doubtful", "loss", "repair", "training",
		"consulting", "legal", "accounting", "subscription", "office",
		"telephone", "internet", "shipping", "freight", "postage",
		"entertainment", "meal", "parking", "fuel", "mileage"}
	return containsAny(kw, keywords)
}

func containsAny(s string, keywords []string) bool {
	for _, kw := range keywords {
		if strings.Contains(s, kw) {
			return true
		}
	}
	return false
}

// Ensure our log import is used
var _ = log.Debug
