package forms

type errors map[string][]string

// Add adds n error message for a given form field
func (e errors) Add(field, message string) {
	e[field] = append(e[field], message)
}

// Get returns the first error message
func (e errors) Get(field string) string {
	// es is the error string
	es := e[field]
	if len(es) == 0 {
		return ""
	}
	return es[0]
}
