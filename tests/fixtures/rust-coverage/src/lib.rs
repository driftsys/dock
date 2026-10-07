pub fn magnitude(value: i32) -> i32 {
    if value < 0 {
        -value
    } else {
        value
    }
}

#[cfg(test)]
mod tests {
    use super::magnitude;

    #[test]
    fn positive_value() {
        assert_eq!(magnitude(7), 7);
    }

    #[test]
    fn negative_value() {
        let expected = if cfg!(feature = "intentional-failure") {
            99
        } else {
            7
        };
        assert_eq!(magnitude(-7), expected);
    }
}
