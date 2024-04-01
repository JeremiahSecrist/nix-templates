fn main() {
    println!("hello world");
}

#[cfg(test)]
mod tests {
    #[test]
    fn allways_true() {
        assert_eq!(true, true);
        assert_eq!(false, false);
    }
}
