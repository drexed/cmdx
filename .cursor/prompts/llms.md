Process the following instructions in the order given:

1. Create an `LLM.md` file
2. Append all files within `docs/**/*.md` into @LLM.md
  2a. Use order outlined in the table of contents of @README.md
  2b. Process one file at a time faster performance and improved accuracy
  2c. Remove the table of contents from the chunk
  2c. Remove the navigations below `---` from the chunk
  2d. Wrap the chunk the files GitHub url the top and a spacer at the bottom like so:
      ```

      ---
      url: https://github.com/drexed/cmdx/blob/main/docs/callbacks.md
      ---

      {{ chunk }}

      ---

      ```
