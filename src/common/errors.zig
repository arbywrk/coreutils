pub const OperandError = error{
    InvalidOperand,
};

pub const OptionError = error{
    UnknownOption,
    MissingOptionArgument,
    UnexpectedArgument,
};
