return [[
;; pester describe blocks
(command
  (command_name)@function_name (#match? @function_name "[Dd][Ee][Ss][Cc][Rr][Ii][Bb][Ee]")
  (command_elements
    (array_literal_expression
      (unary_expression
        (string_literal
          (verbatim_string_characters)@namespace.name
        )
      )
    )
  )
)@namespace.definition

;; pester it blocks
(command
  (command_name)@function_name (#match? @function_name "[Ii][tt]")
  (command_elements
    (array_literal_expression
      (unary_expression
        (string_literal
          (verbatim_string_characters)@test.name
        )
      )
    )
  )
)@test.definition
]]
