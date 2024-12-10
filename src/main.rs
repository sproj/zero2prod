fn main() {
    println!("{}", hello_world());
}

fn hello_world() -> &'static str {
    "Hello, world!"
}

#[cfg(test)]
mod tests {
    use super::hello_world;

    #[test]
    fn should_return_hello() {
        assert_eq!(hello_world(), "Hello, world!");
    }
}
