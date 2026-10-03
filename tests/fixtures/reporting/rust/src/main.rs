fn identity(value: i32) -> i32 {
    value
}

fn main() {
    let value = Some(1).map(|value| identity(value));
    println!("{value:?}");
}
