/**
 * Custom validation function for additional data validation
 * This runs after JSON Schema validation
 * 
 * @param {Object} data - The data to validate
 * @param {Object} schema - The schema used for validation
 * @returns {Object} - { valid: boolean, message?: string, errors?: Array }
 */
function customValidate(data, schema) {
  const errors = [];
  
  // Example: Additional business logic validation
  
  // Check if name is not just a number
  if (data.name && typeof data.name === 'number') {
    errors.push({
      field: 'name',
      message: 'Name cannot be a number'
    });
  }
  
  // Check if age is a valid string number
  if (data.age && typeof data.age === 'string') {
    errors.push({
      field: 'age',
      message: 'Age must be a number, not a string'
    });
  }
  
  // Example: Cross-field validation
  if (data.name && data.age) {
    if (typeof data.name === 'string' && data.name.length > 50) {
      errors.push({
        field: 'name',
        message: 'Name is too long (max 50 characters)'
      });
    }
    
    if (typeof data.age === 'number' && data.age > 150) {
      errors.push({
        field: 'age',
        message: 'Age seems unrealistic (over 150)'
      });
    }
  }
  
  // Return validation result
  if (errors.length > 0) {
    return {
      valid: false,
      message: 'Custom validation failed',
      errors: errors
    };
  }
  
  return {
    valid: true,
    message: 'All custom validations passed'
  };
}

// Example: You can also use AJV if you want more complex validation
// Make sure to include ajv.min.js in your assets if you want to use this
/*
function ajvValidate(data, schema) {
  if (typeof Ajv !== 'undefined') {
    const ajv = new Ajv({ allErrors: true });
    const validate = ajv.compile(schema);
    const valid = validate(data);
    
    return {
      valid: valid,
      errors: validate.errors || []
    };
  }
  
  return {
    valid: false,
    message: 'AJV library not loaded'
  };
}
*/
