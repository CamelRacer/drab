defmodule Drab.Live.HTML do
  @moduledoc false

  @doc """
  Simple html tokenizer. Works with nested lists.

      iex> tokenize("<html> <body >some<b> anything</b></body ></html>")
      [{:tag, "html"}, " ", {:tag, "body "}, "some", {:tag, "b"}, " anything",
      {:tag, "/b"}, {:tag, "/body "}, {:tag, "/html"}]

      iex> tokenize("some")
      ["some"]

      iex> tokenize(["some"])
      [["some"]]

      iex> tokenize("")
      []

      iex> tokenize([""])
      [[]]

      iex> tokenize("<tag> and more")
      [{:tag, "tag"}, " and more"]

      iex> tokenize("<tag> <naked tag")
      [{:tag, "tag"}, " ", {:naked, "naked tag"}]

      iex> tokenize(["<tag a/> <naked tag"])
      [[{:tag, "tag a/"}, " ", {:naked, "naked tag"}]]

      iex> tokenize(["other", "<tag a> <naked tag"])
      [["other"], [{:tag, "tag a"}, " ", {:naked, "naked tag"}]]

      iex> tokenize(["other", :atom, "<tag a/> <naked tag"])
      [["other"], :atom, [{:tag, "tag a/"}, " ", {:naked, "naked tag"}]]
  """
  def tokenize("") do
    []
  end
  def tokenize("<" <> rest) do
    case String.split(rest, ">", parts: 2) do
      [tag] -> [{:naked, String.trim_leading(tag)}] # naked tag can be only at the end
      [tag | tail] -> [{:tag, String.trim_leading(tag)} | tokenize(Enum.join(tail))]
    end
  end
  def tokenize(string) when is_binary(string) do
    case String.split(string, "<", parts: 2) do
      [no_more_tags] -> [no_more_tags]
      [text, rest] -> [text | tokenize("<" <> rest)]
    end
  end
  def tokenize([]) do
    []
  end
  def tokenize([head | tail]) do
    [tokenize(head) | tokenize(tail)]
  end
  def tokenize(other) do
    other
  end

  @doc """
  Detokenizer. Leading spaces in the tags are removed! (< html> becomes <html>).

      iex> html = "<html> <body >some<b> anything</b></body ></html>"
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = "text"
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = ""
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = []
      iex> html |> tokenize() |> tokenized_to_html()
      ""

      iex> html = [""]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = "<tag> <naked tag"
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = "<  tag> < naked tag"
      iex> html |> tokenize() |> tokenized_to_html()
      "<tag> <naked tag"

      iex> html = ["other", "<tag a> <naked tag"]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = ["other", "<t>a</t>", "<tag a> <naked tag"]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = ["other", ["<t>a</t>", "<tag a> <naked tag"]]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = ["other", [["<t>a</t>"], "<tag a> </tag>"]]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = ["other", :atom, "<tag a> </tag>"]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> html = ["other", [:atom, "<tag a> </tag>"]]
      iex> html |> tokenize() |> tokenized_to_html() == html
      true

      iex> tok = [["other"], [:atom, [{:tag, "tag a"}, " ", {:tag, "/tag"}], {:other}]]
      iex> tokenized_to_html(tok)
      ["other", [:atom, "<tag a> </tag>", {:other}]]
  """
  def tokenized_to_html([]), do: ""
  def tokenized_to_html({:tag, tag}), do: "<#{tag}>"
  def tokenized_to_html({:naked, tag}), do: "<#{tag}"
  def tokenized_to_html(text) when not is_list(text), do: text
  def tokenized_to_html([list]) when is_list(list), do: [tokenized_to_html(list)]
  def tokenized_to_html([head | tail]) when is_list(head), do: [tokenized_to_html(head) | tokenized_to_html(tail)]
  def tokenized_to_html([head | tail]) do
    t = tokenized_to_html(tail)
    case tokenized_to_html(head) do
      h when is_binary(h) -> h <> t
      h -> if t == "", do: [h], else: [h | t]
    end
  end

  @doc """
  Injects given attribute to the last found opened (or naked) tag.

    iex> inject_attribute_to_last_opened "<tag>", "attr=1"
    {:ok, "<tag attr=1>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag attr2>", "attr=1"
    {:ok, "<tag attr=1 attr2>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag attr2><tag></tag>", "attr=1"
    {:ok, "<tag attr=1 attr2><tag></tag>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag></tag><tag attr2", "attr=1"
    {:ok, "<tag></tag><tag attr=1 attr2", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag><tag attr2", "attr=1"
    {:ok, "<tag><tag attr=1 attr2", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag><tag attr2>", "attr=1"
    {:ok, "<tag><tag attr=1 attr2>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag><hr/><tag attr2></tag>", "attr=1"
    {:ok, "<tag attr=1><hr/><tag attr2></tag>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag><br><tag attr2></tag>", "attr=1"
    {:ok, "<tag attr=1><br><tag attr2></tag>", "attr=1"}

    iex> inject_attribute_to_last_opened "<img src", "attr=1"
    {:ok, "<img attr=1 src", "attr=1"}

    iex> inject_attribute_to_last_opened "<hr>", "attr=1"
    {:not_found, "<hr>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag 1><tag 2><tag 3></tag>", "attr=1"
    {:ok, "<tag 1><tag attr=1 2><tag 3></tag>", "attr=1"}

    iex> inject_attribute_to_last_opened "<tag 1><tag 2><tag 3></tag></tag>", "attr='3'"
    {:ok, "<tag attr='3' 1><tag 2><tag 3></tag></tag>", "attr='3'"}

    iex> inject_attribute_to_last_opened "<tag 1></tag>", "attr=x"
    {:not_found, "<tag 1></tag>", "attr=x"}

    iex> inject_attribute_to_last_opened "text only", "attr=x"
    {:not_found, "text only", "attr=x"}

    iex> inject_attribute_to_last_opened "<tag 1><tag 2><tag 3></tag></tag></tag>", "attr=x"
    {:not_found, "<tag 1><tag 2><tag 3></tag></tag></tag>", "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag 1><tag 2><tag 3></tag>", "</tag>"], "attr=x"
    {:ok, ["<tag attr=x 1><tag 2><tag 3></tag>", "</tag>"], "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag 1><tag 2><tag 3></tag>", :atom, "</tag>"], "attr=x"
    {:ok, ["<tag attr=x 1><tag 2><tag 3></tag>", :atom, "</tag>"], "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag 1><tag 2>", "text", "<tag 3></tag>", "</tag>"], "attr=x"
    {:ok, ["<tag attr=x 1><tag 2>", "text", "<tag 3></tag>", "</tag>"], "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag 1><tag 2>", ["<tag 3>", "</tag>"]], "attr=x"
    {:ok, ["<tag 1><tag attr=x 2>", ["<tag 3>", "</tag>"]], "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag 1><tag 2>", {:other}, ["<tag 3>", "</tag>"]], "attr=x"
    {:ok, ["<tag 1><tag attr=x 2>", {:other}, ["<tag 3>", "</tag>"]], "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag 1><tag 2>", {}, ["<tag 3>", :atom, "</tag>", {}]], "attr=x"
    {:ok, ["<tag 1><tag attr=x 2>", {}, ["<tag 3>", :atom, "</tag>", {}]], "attr=x"}

    iex> inject_attribute_to_last_opened ["<tag attr=42 1><tag 2><tag 3></tag>", "</tag>"], "attr=x"
    {:already_there, ["<tag attr=42 1><tag 2><tag 3></tag>", "</tag>"], "attr=42"}

    iex> inject_attribute_to_last_opened "<img attr=2 src", "attr=1"
    {:already_there, "<img attr=2 src", "attr=2"}
  """
  def inject_attribute_to_last_opened(html, attribute) do
    {_, found, acc} = html
      |> tokenize()
      |> deep_reverse()
      |> do_inject(attribute, [], :not_found, [])
    acc = tokenized_to_html(acc)
    case found do
      result when is_atom(result) -> {result, acc, attribute}
      result when is_binary(result) -> {:already_there, acc, result}
    end
  end

  @non_closing_tags ~w{
    area base br col embed hr img input keygen link meta param source track wbr
    area/ base/ br/ col/ embed/ hr/ img/ input/ keygen/ link/ meta/ param/ source/ track/ wbr/
  }
  defp do_inject([], _, opened, found, acc) do
    {opened, found, acc}
  end
  defp do_inject([head | tail], attribute, opened, found, acc) do
    case head do
      {:naked, tag} -> # naked can be only at the end
        {result, injected} = case find_attribute(tag, attribute) do
          nil -> {:ok, {:naked, add_attribute(tag, attribute)}}
          found_attr -> {found_attr, head}
        end
        do_inject(tail, attribute, opened, result, [injected | acc])
      {:tag, "/" <> tag} ->
        do_inject(tail, attribute, [tag_name(tag) | opened], found, [head | acc])
      {:tag, tag} ->
        if Enum.find(opened, fn x -> tag_name(tag) == x end) do
          do_inject(tail, attribute, opened -- [tag_name(tag)], found, [head | acc])
        else
          if found != :not_found || Enum.member?(@non_closing_tags, tag_name(tag)) do
            do_inject(tail, attribute, opened, found, [head | acc])
          else
            {result, injected} = case find_attribute(tag, attribute) do
              nil -> {:ok, {:tag, add_attribute(tag, attribute)}}
              found_attr -> {found_attr, head}
            end
            do_inject(tail, attribute, opened, result, [injected | acc])
          end
        end
      list when is_list(list) ->
        {op, fd, ac} = do_inject(list, attribute, opened, found, [])
        do_inject(tail, attribute, op, fd, [ac | acc])
      _ ->
        do_inject(tail, attribute, opened, found, [head | acc])
    end
  end

  defp tag_name(tag) do
    String.split(tag, ~r/\s/) |> List.first()
  end

  @doc """
  Add attribute to a tag.

      iex> add_attribute("tag tag=2", "attr=1")
      "tag attr=1 tag=2"
  """
  def add_attribute(tag, attribute) do
    String.replace(tag, tag_name(tag), "#{tag_name(tag)} #{attribute}", global: false)
  end

  @doc """
  Find an existing attribute

      iex> find_attribute("tag attrx=1 attr='2' attra=4", "attr=3")
      "attr='2'"

      iex> find_attribute("tag attrx=1 attra=4", "attr=3")
      nil

      iex> find_attribute("tag ", "attr=3")
      nil

      iex> find_attribute("tag attrx = 1 attr = '2' attra= 4 ", "attr = 3")
      "attr='2'"
  """
  def find_attribute(tag, attr) do
    [attr_name | _] = attr
      |> trim_attr()
      |> String.split("=", parts: 2)
    # attr_name = String.trim(attr_name)

    case Regex.run(~r/(#{attr_name}\s*=\s*\S+)/, tag, capture: :first) do
      [att] -> trim_attr(att)
      other -> other
    end
  end

  defp trim_attr(attr) do
    [attr_name, attr_value] = String.split(attr, "=", parts: 2)
    attr_name = String.trim(attr_name)
    attr_value = String.trim(attr_value)
    attr_name <> "=" <> attr_value
  end

  @doc """
  Converts buffer to html. Nested expressions are ignored.
  """
  def to_flat_html(body), do: do_to_flat_html(body) |> List.flatten() |> Enum.join()

  defp do_to_flat_html([]), do: []
  defp do_to_flat_html(body) when is_binary(body), do: [body]
  defp do_to_flat_html({_, _, list}) when is_list(list), do: do_to_flat_html(list)
  defp do_to_flat_html([head | rest]), do: do_to_flat_html(head) ++ do_to_flat_html(rest)
  defp do_to_flat_html(_), do: []


  @doc """
  Returns amperes and patterns from flat html.
  Pattern is processed by Floki, so it doesn't have to be the same as original!
  """
  def amperes_from_buffer({:safe, buffer}) when is_list(buffer) do
    # amperes_from_html(to_flat_html(buffer))
    #   |> Map.merge(amperes_from_expressions(buffer))
    deep_find_htmls({:safe, buffer})
  end

  # defp amperes_from_expressions({:safe, buffer}) do
  #   amperes_from_html(to_flat_html(buffer))
  #     |> amperes_from_expressions(buffer)
  # end

  defp deep_find_htmls([]), do: %{}
  defp deep_find_htmls({:safe, body}) do
    Map.merge(amperes_from_html(body), deep_find_htmls(body))
  end
  defp deep_find_htmls({:do, body}), do: deep_find_htmls(body)
  defp deep_find_htmls([{_, _, args} | tail]) when is_list(args) do
    Map.merge(deep_find_htmls(args), deep_find_htmls(tail))
  end
  defp deep_find_htmls([_ | tail]), do: deep_find_htmls(tail)

  defp amperes_from_html(list) when is_list(list), do: amperes_from_html(to_flat_html(list))
  defp amperes_from_html(html) do
    html = Floki.parse(html)
    for {tag, attributes, inner_html} <- Floki.find(html, "[drab-ampere]"), into: Map.new() do
      {_, ampere} = Enum.find attributes, fn {name, _} -> name == "drab-ampere" end
      {ampere, {:html, tag, Floki.raw_html(inner_html)}}
    end
  end

  @doc """
  Deep reverse of the list

      iex> deep_reverse [1,2,3]
      [3,2,1]

      iex> deep_reverse [[1,2],[3,4]]
      [[4,3], [2,1]]

      iex> deep_reverse [[[1,2], [3,4]], [5,6]]
      [[6,5], [[4,3], [2,1]]]

      iex> deep_reverse [1, [2, 3], 4]
      [4, [3, 2], 1]
  """
  def deep_reverse(list) do
    list |> Enum.reverse() |> Enum.map(fn
      x when is_list(x) -> deep_reverse(x)
      x -> x
    end)
  end
end