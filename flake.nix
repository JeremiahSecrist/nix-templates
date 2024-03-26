{
  outputs = inputs: with inputs; {
    templates = {
      rust = {
        path = ./rust;
        description = "Standard configuration for new rust projects.";
      };
    };
  };
}
