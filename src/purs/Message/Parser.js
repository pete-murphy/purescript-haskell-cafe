export const parseRFC2822 = (left) => (right) => (input) => {
  let result;
  try {
    result = new Date(input);
  } catch (error) {
    return left(error);
  }
  return right(result);
};
