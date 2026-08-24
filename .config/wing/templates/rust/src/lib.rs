//! {{PROJECT_NAME}}.

/// Returns this crate's display name.
pub fn name() -> &'static str {
    "{{PROJECT_NAME}}"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_name() {
        assert_eq!(name(), "{{PROJECT_NAME}}");
    }
}
